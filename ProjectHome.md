# xqOAI #
<p>
xqOAI is an OAI-PMH data provider implemented in the XQuery language, and is fully conformant to the OAI-PMH 2.0 specification.  It provides harvestable OAI-Dublin Core XML records.  The <a href='http://diglib.princeton.edu/oai?verb=Identify'>Princeton instance</a> sits atop the X-Hive/DB native XML database, hooking into MODS and EAD records, but generally serves as a standards-based harvesting layer atop an XML data-store.<br>
</p>
<p>
In addition to the core OAI-PMH service, three modules are included for extracting OAI-Dublin Core information from MODS records, extracting OAI-DC from EAD records, and retrieving the time of the last record update via the X-Hive/DB API.<br>
</p>
<p>
Browse the <a href='http://code.google.com/p/xqoai/source/browse/'>source code</a> if you wish.<br>
</p>
<h2>Availability</h2>
<p>
You may check the code out freely:<br>
</p>
```
svn checkout http://xqoai.googlecode.com/svn/trunk/ xqoai-read-only  
```

<h2>License</h2>
<p>
xqOAI is released under the <a href='LICENSE.md'>MIT/X11 license</a>.<br>
</p>