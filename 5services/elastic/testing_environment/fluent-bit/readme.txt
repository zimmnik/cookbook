docker run -it --rm -v ${PWD}/conf:/conf:ro fluent/fluent-bit:1.3.2-debug /fluent-bit/bin/fluent-bit -v -c /conf/fb.conf && > app.log
