test_pcm_nrz: test_pcm_nrz.v pcm_nrz.v uart_tx.v
	iverilog -o $@ $^

.phony: run
run: test_pcm_nrz
	vvp test_pcm_nrz -fst
