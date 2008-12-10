module Sequel
  class Dataset
    private
    # This is run inside .all, after all
    # of the records have been loaded
    # via .each, but before any block passed
    # to all is called.  It is called with
    # a single argument, an array of all
    # returned records.
    def post_load(all_records)
    end
  end
end
