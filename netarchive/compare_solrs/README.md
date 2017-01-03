## Introduction
We need to test the performance difference between Solr versions for Netarchive Search at Statsbiblioteket. Our shards are ~900GB in size and currently (2016-11-25) we do not have multi-terabytes of undisturbed SSDs set aside for testing.

This project tages one single shard and constructs smaller test-shards from that, which are then converted to different Lucene/Solr index versions. The aim is to test

 1.1 Solr 4.10 sparse (the current implementation)
 1.2 Solr 4.10
 2.0 Solr 5.5
 3.0 Solr 6.3
 4.0 Solr trunk (7.0.0)
 5.0 Solr trunk + https://issues.apache.org/jira/browse/LUCENE-7521

For each version, the test-suite ../netarchive_performance is used to perform test simulating researcher use of the danish net archive. The test should probe

 * SSD vs. spinning drives
 * Single shard vs. distributed (2 shards)
 * Single segment vs. multi-segment
 * Faceting none/vanilla/sparse

## Goals
 1. Fully automated construction of test-shards
 2. Fully automated test of the full suite of combinations

## Product
Collected performance data, visualized as graphs, hopefully making it clear if there are any performance pitfalls for a future upgrade from Solr 4.10 to 6.3.

Secondary, the results should hopefully verify/debunk commonly shared Solr advices, such as "The overhead of having multi-segment vs. single segment indexes is low" and "Use multi-shard if the index exceeds 100GB".

## Requirements
At least 1.5TB of storage space for creating the test shards.
