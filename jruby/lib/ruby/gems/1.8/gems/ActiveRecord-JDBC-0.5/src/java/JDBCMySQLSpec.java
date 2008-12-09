/***** BEGIN LICENSE BLOCK *****
 * Version: CPL 1.0/GPL 2.0/LGPL 2.1
 *
 * The contents of this file are subject to the Common Public
 * License Version 1.0 (the "License"); you may not use this file
 * except in compliance with the License. You may obtain a copy of
 * the License at http://www.eclipse.org/legal/cpl-v10.html
 *
 * Software distributed under the License is distributed on an "AS
 * IS" basis, WITHOUT WARRANTY OF ANY KIND, either express or
 * implied. See the License for the specific language governing
 * rights and limitations under the License.
 *
 * Copyright (C) 2007 Ola Bini <ola.bini@gmail.com>
 * 
 * Alternatively, the contents of this file may be used under the terms of
 * either of the GNU General Public License Version 2 or later (the "GPL"),
 * or the GNU Lesser General Public License Version 2.1 or later (the "LGPL"),
 * in which case the provisions of the GPL or the LGPL are applicable instead
 * of those above. If you wish to allow use of your version of this file only
 * under the terms of either the GPL or the LGPL, and not to allow others to
 * use your version of this file under the terms of the CPL, indicate your
 * decision by deleting the provisions above and replace them with the notice
 * and other provisions required by the GPL or the LGPL. If you do not delete
 * the provisions above, a recipient may use your version of this file under
 * the terms of any one of the CPL, the GPL or the LGPL.
 ***** END LICENSE BLOCK *****/

import org.jruby.Ruby;
import org.jruby.RubyModule;
import org.jruby.RubyString;

import org.jruby.runtime.CallbackFactory;
import org.jruby.runtime.ThreadContext;
import org.jruby.runtime.builtin.IRubyObject;

import org.jruby.util.ByteList;

public class JDBCMySQLSpec {
    public static void load(Ruby runtime, RubyModule jdbcSpec) {
        RubyModule mysql = jdbcSpec.defineModuleUnder("MySQL");
        CallbackFactory cf = runtime.callbackFactory(JDBCMySQLSpec.class);
        mysql.defineFastMethod("quote_string",cf.getFastSingletonMethod("quote_string",IRubyObject.class));
    }

    private final static ByteList ZERO = new ByteList(new byte[]{'\\','0'});
    private final static ByteList NEWLINE = new ByteList(new byte[]{'\\','n'});
    private final static ByteList CARRIAGE = new ByteList(new byte[]{'\\','r'});
    private final static ByteList ZED = new ByteList(new byte[]{'\\','Z'});
    private final static ByteList DBL = new ByteList(new byte[]{'\\','"'});
    private final static ByteList SINGLE = new ByteList(new byte[]{'\\','\''});
    private final static ByteList ESCAPE = new ByteList(new byte[]{'\\','\\'});

    public static IRubyObject quote_string(IRubyObject recv, IRubyObject string) {
        boolean replacementFound = false;
        ByteList bl = ((RubyString) string).getByteList();
        
        for(int i = bl.begin; i < bl.begin + bl.realSize; i++) {
            ByteList rep = null;
            switch (bl.bytes[i]) {
            case 0: rep = ZERO; break;
            case '\n': rep = NEWLINE; break;
            case '\r': rep = CARRIAGE; break;
            case 26: rep = ZED; break;
            case '"': rep = DBL; break;
            case '\'': rep = SINGLE; break;
            case '\\': rep = ESCAPE; break;
            default: continue;
            }
            
            // On first replacement allocate a different bytelist so we don't manip original 
            if(!replacementFound) {
                i-= bl.begin;
                bl = new ByteList(bl);
                replacementFound = true;
            }

            bl.replace(i, 1, rep);
            i+=1;
        }
        return recv.getRuntime().newStringShared(bl);
    }
}
