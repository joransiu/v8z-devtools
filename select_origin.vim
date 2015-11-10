
:call search("<<<<", "cW")
:normal! dd
:call search("=======", "W")
:normal! V
:call search(">>>>>>>", "W")
:normal! d
:call search("<<<<<", "cW")
:normal! zt

