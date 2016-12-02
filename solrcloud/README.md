# Scripts for automating SolrCloud setup for different Solr versions

* get_solr.sh
   Downloads and (if needed) compiles the Solr versions
 * cloud_install.sh VERSION
   Installs a SolrCloud with the given version
 * cloud_start.sh VERSION
   Starts ZooKeepers and Solrs for the given version
 * cloud_stop.sh
   Stops any running SolrCloud
 * drop_cache.sh
   Clears the IO cache of the operating system
   Note: drop_cache.sh needs to be executed with sudo, or it can be set to always run as root with
   ```
   sudo chown root.root drop_cache.sh
   sudo chmod 4755 drop_cache.sh
   ```
