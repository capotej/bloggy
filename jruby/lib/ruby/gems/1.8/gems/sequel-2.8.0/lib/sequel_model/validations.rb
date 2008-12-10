module Sequel
  class Model
    # Validations without an :if option are always run
    DEFAULT_VALIDATION_IF_PROC = proc{true}

    # The Validation module houses a couple of classes used by Sequel's
    # validation code.
    module Validation
      # Validation::Errors represents validation errors, a simple hash subclass
      # with a few convenience methods.
      class Errors < ::Hash
        # Assign an array of messages for each attribute on access
        def initialize
          super{|h,k| h[k] = []}
        end

        # Adds an error for the given attribute.
        def add(att, msg)
          self[att] << msg
        end

        # Return the total number of error messages.
        def count
          full_messages.length
        end
        
        # Returns an array of fully-formatted error messages.
        def full_messages
          inject([]) do |m, kv| 
            att, errors = *kv
            errors.each {|e| m << "#{Array(att).join(' and ')} #{e}"}
            m
          end
        end
        
        # Returns the array of errors for the given attribute, or nil
        # if there are no errors for the attribute.
        def on(att)
          self[att] if include?(att)
        end
      end
  
      # The Generator class is used to generate validation definitions using 
      # the validates {} idiom.
      class Generator
        # Initializes a new generator.
        def initialize(receiver ,&block)
          @receiver = receiver
          instance_eval(&block)
        end
    
        # Delegates method calls to the receiver by calling receiver.validates_xxx.
        def method_missing(m, *args, &block)
          @receiver.send(:"validates_#{m}", *args, &block)
        end
      end
    end

    # Returns true if validations are defined.
    def self.has_validations?
      !validations.empty?
    end

    # Instructs the model to skip validations defined in superclasses
    def self.skip_superclass_validations
      @skip_superclass_validations = true
    end
    
    # Defines validations by converting a longhand block into a series of 
    # shorthand definitions. For example:
    #
    #   class MyClass
    #     include Validation
    #     validates do
    #       length_of :name, :minimum => 6
    #       length_of :password, :minimum => 8
    #     end
    #   end
    #
    # is equivalent to:
    #   class MyClass
    #     include Validation
    #     validates_length_of :name, :minimum => 6
    #     validates_length_of :password, :minimum => 8
    #   end
    def self.validates(&block)
      Validation::Generator.new(self, &block)
    end

    # Validates the given instance.
    def self.validate(o)
      if superclass.respond_to?(:validate) && !@skip_superclass_validations
        superclass.validate(o)
      end
      validations.each do |att, procs|
        v = case att
        when Array
          att.collect{|a| o.send(a)}
        else
          o.send(att)
        end
        procs.each {|tag, p| p.call(o, att, v)}
      end
    end
    
    # Validates acceptance of an attribute.  Just checks that the value
    # is equal to the :accept option.
    #
    # Possible Options:
    # * :accept - The value required for the object to be valid (default: '1')
    # * :allow_blank - Whether to skip the validation if the value is blank (default: false)
    # * :allow_nil - Whether to skip the validation if the value is nil (default: true)
    # * :if - A symbol (indicating an instance_method) or proc (which is instance_evaled)
    #   skipping this validation if it returns nil or false.
    # * :message - The message to use (default: 'is not accepted')
    # * :tag - The tag to use for this validation (default: :acceptance)
    def self.validates_acceptance_of(*atts)
      opts = {
        :message => 'is not accepted',
        :allow_nil => true,
        :accept => '1'
      }.merge!(atts.extract_options!)
      
      atts << {:if=>opts[:if], :tag=>opts[:tag]||:acceptance}
      validates_each(*atts) do |o, a, v|
        next if (v.nil? && opts[:allow_nil]) || (v.blank? && opts[:allow_blank])
        o.errors[a] << opts[:message] unless v == opts[:accept]
      end
    end

    # Validates confirmation of an attribute. Checks that the object has
    # a _confirmation value matching the current value.  For example:
    #
    #   validates_confirmation_of :blah
    #
    # Just makes sure that object.blah = object.blah_confirmation.  Often used for passwords
    # or email addresses on web forms.
    #
    # Possible Options:
    # * :allow_false - Whether to skip the validation if the value is blank (default: false)
    # * :allow_nil - Whether to skip the validation if the value is nil (default: false)
    # * :if - A symbol (indicating an instance_method) or proc (which is instance_evaled)
    #   skipping this validation if it returns nil or false.
    # * :message - The message to use (default: 'is not confirmed')
    # * :tag - The tag to use for this validation (default: :confirmation)
    def self.validates_confirmation_of(*atts)
      opts = {
        :message => 'is not confirmed',
      }.merge!(atts.extract_options!)
     
      atts << {:if=>opts[:if], :tag=>opts[:tag]||:confirmation}
      validates_each(*atts) do |o, a, v|
        next if (v.nil? && opts[:allow_nil]) || (v.blank? && opts[:allow_blank])
        c = o.send(:"#{a}_confirmation")
        o.errors[a] << opts[:message] unless v == c
      end
    end

    # Adds a validation for each of the given attributes using the supplied
    # block. The block must accept three arguments: instance, attribute and 
    # value, e.g.:
    #
    #   validates_each :name, :password do |object, attribute, value|
    #     object.errors[attribute] << 'is not nice' unless value.nice?
    #   end
    #
    # Possible Options:
    # * :if - A symbol (indicating an instance_method) or proc (which is instance_evaled)
    #   skipping this validation if it returns nil or false.
    # * :tag - The tag to use for this validation (default: nil)
    def self.validates_each(*atts, &block)
      opts = atts.extract_options!
      blk = if opts[:if]
        proc{|o,a,v| block.call(o,a,v) if o.instance_eval(&if_proc(opts))}
      else
        block
      end
      tag = opts[:tag]
      atts.each do |a| 
        a_vals = validations[a]
        if tag && (old = a_vals.find{|x| x[0] == tag})
          old[1] = blk
        else
          a_vals << [tag, blk]
        end
      end
    end

    # Validates the format of an attribute, checking the string representation of the
    # value against the regular expression provided by the :with option.
    #
    # Possible Options:
    # * :allow_blank - Whether to skip the validation if the value is blank (default: false)
    # * :allow_nil - Whether to skip the validation if the value is nil (default: false)
    # * :if - A symbol (indicating an instance_method) or proc (which is instance_evaled)
    #   skipping this validation if it returns nil or false.
    # * :message - The message to use (default: 'is invalid')
    # * :tag - The tag to use for this validation (default: :format)
    # * :with - The regular expression to validate the value with (required).
    def self.validates_format_of(*atts)
      opts = {
        :message => 'is invalid',
      }.merge!(atts.extract_options!)
      
      unless opts[:with].is_a?(Regexp)
        raise ArgumentError, "A regular expression must be supplied as the :with option of the options hash"
      end
      
      atts << {:if=>opts[:if], :tag=>opts[:tag]||:format}
      validates_each(*atts) do |o, a, v|
        next if (v.nil? && opts[:allow_nil]) || (v.blank? && opts[:allow_blank])
        o.errors[a] << opts[:message] unless v.to_s =~ opts[:with]
      end
    end

    # Validates the length of an attribute.
    #
    # Possible Options:
    # * :allow_blank - Whether to skip the validation if the value is blank (default: false)
    # * :allow_nil - Whether to skip the validation if the value is nil (default: false)
    # * :if - A symbol (indicating an instance_method) or proc (which is instance_evaled)
    #   skipping this validation if it returns nil or false.
    # * :is - The exact size required for the value to be valid (no default)
    # * :maximum - The maximum size allowed for the value (no default)
    # * :message - The message to use (no default, overrides :too_long, :too_short, and :wrong_length
    #   options if present)
    # * :minimum - The minimum size allowed for the value (no default)
    # * :tag - The tag to use for this validation (default: :length)
    # * :too_long - The message to use use if it the value is too long (default: 'is too long')
    # * :too_short - The message to use use if it the value is too short (default: 'is too short')
    # * :with - The array/range that must include the size of the value for it to be valid (no default)
    # * :wrong_length - The message to use use if it the value is not valid (default: 'is the wrong length')
    def self.validates_length_of(*atts)
      opts = {
        :too_long     => 'is too long',
        :too_short    => 'is too short',
        :wrong_length => 'is the wrong length'
      }.merge!(atts.extract_options!)
      
      tag = if opts[:tag]
        opts[:tag]
      else
       ([:length] + [:maximum, :minimum, :is, :within].reject{|x| !opts.include?(x)}).join('-').to_sym
      end
      atts << {:if=>opts[:if], :tag=>tag}
      validates_each(*atts) do |o, a, v|
        next if (v.nil? && opts[:allow_nil]) || (v.blank? && opts[:allow_blank])
        if m = opts[:maximum]
          o.errors[a] << (opts[:message] || opts[:too_long]) unless v && v.size <= m
        end
        if m = opts[:minimum]
          o.errors[a] << (opts[:message] || opts[:too_short]) unless v && v.size >= m
        end
        if i = opts[:is]
          o.errors[a] << (opts[:message] || opts[:wrong_length]) unless v && v.size == i
        end
        if w = opts[:within]
          o.errors[a] << (opts[:message] || opts[:wrong_length]) unless v && w.include?(v.size)
        end
      end
    end

    # Validates whether an attribute is a number.
    #
    # Possible Options:
    # * :allow_blank - Whether to skip the validation if the value is blank (default: false)
    # * :allow_nil - Whether to skip the validation if the value is nil (default: false)
    # * :if - A symbol (indicating an instance_method) or proc (which is instance_evaled)
    #   skipping this validation if it returns nil or false.
    # * :message - The message to use (default: 'is not a number')
    # * :tag - The tag to use for this validation (default: :numericality)
    # * :only_integer - Whether only integers are valid values (default: false)
    def self.validates_numericality_of(*atts)
      opts = {
        :message => 'is not a number',
      }.merge!(atts.extract_options!)
      
      atts << {:if=>opts[:if], :tag=>opts[:tag]||:numericality}
      validates_each(*atts) do |o, a, v|
        next if (v.nil? && opts[:allow_nil]) || (v.blank? && opts[:allow_blank])
        begin
          if opts[:only_integer]
            Kernel.Integer(v.to_s)
          else
            Kernel.Float(v.to_s)
          end
        rescue
          o.errors[a] << opts[:message]
        end
      end
    end

    # Validates the presence of an attribute.  Requires the value not be blank,
    # with false considered present instead of absent.
    #
    # Possible Options:
    # * :if - A symbol (indicating an instance_method) or proc (which is instance_evaled)
    #   skipping this validation if it returns nil or false.
    # * :message - The message to use (default: 'is not present')
    # * :tag - The tag to use for this validation (default: :presence)
    def self.validates_presence_of(*atts)
      opts = {
        :message => 'is not present',
      }.merge!(atts.extract_options!)
      
      atts << {:if=>opts[:if], :tag=>opts[:tag]||:presence}
      validates_each(*atts) do |o, a, v|
        o.errors[a] << opts[:message] if v.blank? && v != false
      end
    end

    # Validates only if the fields in the model (specified by atts) are
    # unique in the database.  Pass an array of fields instead of multiple
    # fields to specify that the combination of fields must be unique,
    # instead of that each field should have a unique value.
    #
    # You should also add a unique index in the
    # database, as this suffers from a fairly obvious race condition.
    #
    # Possible Options:
    # * :allow_nil - Whether to skip the validation if the value(s) is/are nil (default: false)
    # * :if - A symbol (indicating an instance_method) or proc (which is instance_evaled)
    #   skipping this validation if it returns nil or false.
    # * :message - The message to use (default: 'is already taken')
    # * :tag - The tag to use for this validation (default: :uniqueness)
    def self.validates_uniqueness_of(*atts)
      opts = {
        :message => 'is already taken',
      }.merge!(atts.extract_options!)

      atts << {:if=>opts[:if], :tag=>opts[:tag]||:uniqueness}
      validates_each(*atts) do |o, a, v|
        error_field = a
        a = Array(a)
        v = Array(v)
        next unless v.any? or opts[:allow_nil] == false
        ds = o.class.filter(a.zip(v))
        num_dups = ds.count
        allow = if num_dups == 0
          # No unique value in the database
          true
        elsif num_dups > 1
          # Multiple "unique" values in the database!!
          # Someone didn't add a unique index
          false
        elsif o.new?
          # New record, but unique value already exists in the database
          false
        elsif ds.first === o
          # Unique value exists in database, but for the same record, so the update won't cause a duplicate record
          true
        else
          false
        end
        o.errors[error_field] << opts[:message] unless allow
      end
    end

    # Returns the validations hash for the class.
    def self.validations
      @validations ||= Hash.new {|h, k| h[k] = []}
    end
    
    ### Private Class Methods ###

    def self.if_proc(opts) # :nodoc:
      case opts[:if]
      when Symbol then proc{send opts[:if]}
      when Proc then opts[:if]
      when nil then DEFAULT_VALIDATION_IF_PROC
      else raise(::Sequel::Error, "invalid value for :if validation option")
      end
    end

    private_class_method :if_proc

    ### Instance Methods ###
  
    # Returns the validation errors associated with the object.
    def errors
      @errors ||= Validation::Errors.new
    end

    # Validates the object.
    def validate
      errors.clear
      return false if before_validation == false
      self.class.validate(self)
      after_validation
      nil
    end

    # Validates the object and returns true if no errors are reported.
    def valid?
      return false if validate == false
      errors.empty?
    end
  end
end
