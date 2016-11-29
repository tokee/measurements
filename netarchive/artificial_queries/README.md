# measurements - netarchive - artificial queries


A test against the full Netarchive Search as Statsbiblioteket (80TB / 16 billion documents).
Note that due to Danish legislation, the raw results from the tests are not stored in the repository.
Danish legislation

*** Queries
Created by extracting top 50K terms from the fulltext field of a random shard, eliminating the non-text based ones as well as the top ones (these should be tested independently to see how huge posting lists are handled) and using 1-n random terms for a query. Testing should be done against groups of queries where each group has the same number of terms.

*** Faceting
Only standard facets (no faceting on URL as that is rarely used).

*** Grouping
Maybe?

*** Stats
Maybe?



Instructions:
./get_top.sh
Constructs artificial queries used by the test script.

./run_tests.sh
Executes a test using the queries from the top scrips.

./extract_results.sh
Produces graphs over the result from the test script.


TODO: Isolate the internal Statsbiblioteket machines & ports from the other configurations so that the configuration for each test can be shared freely.
