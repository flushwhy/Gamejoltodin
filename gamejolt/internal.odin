package gamejolt

import "base:runtime"
import "core:crypto/legacy/md5"
import "core:encoding/json"
import "core:fmt"
import "core:slice"
import "core:strconv"
import "core:strings"
import "vendor:curl"

// The Odin curl vendor package disables the default static CRT library on
// Windows. Explicitly link the Universal CRT so shared-library builds resolve
// standard C memory routines without fighting the vendor's /NODEFAULTLIB flag.
when ODIN_OS == .Windows {
    foreign import ucrt "system:ucrt.lib"
}
