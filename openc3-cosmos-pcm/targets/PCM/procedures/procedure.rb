# Script Runner test script
cmd("PCM EXAMPLE")
wait_check("PCM STATUS BOOL == 'FALSE'", 5)
