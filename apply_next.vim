
let file = "code-stubs-s390.cc"
let path = "/home/nodedev/v8z-disk/4.6/v8z-4.7/v8/src/s390/"
let start = search('^@@.\+@@', "cW")
let end = search('^@@.\+@@\|^diff', "W") - 1
echo start . " " . end
exe ":" . start . "," . end . "!patch -F100 --merge " . path . file
normal! zt

