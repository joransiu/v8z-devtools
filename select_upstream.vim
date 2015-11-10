
let head = search("<<<<<<<", "cW")
let midd = search("=======", "W")
execute ":" . head . "," . midd . "d"

let tail = search(">>>>>>>", "cW")
execute ":" . tail . "," . tail . "d"
