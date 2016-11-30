# comparison 20161130

## Generation of graphs for sbdevel blog entry

```
cd ..
CUSTOM_GP="set key center top" CONF=20161130_comparison/compare_high.conf ./compare.sh "20161129-1106_full_Facets sparse-facets" "20161129-1241_full_SolrFacets solr-facets" ; mv compare_sparse-facets_solr-facets.png 20161130_comparison/compare_sparse-facets_solr-facets_20161130.png

CUSTOM_GP="set key center top" CONF=20161130_comparison/compare_low.conf ./compare.sh "20161125-1528_full_NoFacets no-facets" "20161129-1106_full_Facets sparse-facets" ; mv compare_no-facets_sparse-facets.png 20161130_comparison/compare_no-facets_sparse-facets_20161130.png

```