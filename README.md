AMD 3990X Threadripper
uwsgi 40 processes, 1 thread
linux@solar ~/P/u/p/zsgi (master)> wrk -c 100 -d 10 -t 100 http://localhost:8080
Running 10s test @ http://localhost:8080
  100 threads and 100 connections
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency   501.44us  452.18us  17.45ms   94.13%
    Req/Sec   249.19    246.50     1.33k    82.70%
  247356 requests in 10.10s, 12.97MB read
  Socket errors: connect 0, read 247356, write 1, timeout 0
Requests/sec:  24484.19

