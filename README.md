# Affiliations

## Affiliations adds a dataset, plugins and methods to render, import and export author affiliations

It provides
- a generic affiliation dataset for affiliations from Scopus, ROR, or Grid
- plugins and a script to import data from Scopus and match affiliations to author names.
  At University of Zurich, we decided to use Scopus because it provided the best coverage
  of standardised affiliation data compared to Crossref or PubMed.
- DataCite XML Metadata Schema export plugin, updated to Schema 4.3 and to affiliation 
  export
- Highwire Press export plugin for Google Scholar harvesting
- snippets of field definitions and render methods for capturing and rendering affiliation
  and correspondence data. Correspondence information can be used for Open Access 
  monitoring.
    
### Data Model

When an author publishes, he/she might indicate several affiliations (aka work places) 
in the publication. This is quite common, over 13% of authors have 2 or more affiliations
according to our observation.

In an ideal database world, this would be modeled in a n:m relation between author table
and affiliation, usually modeled by resolving it to 1:n and 1:m relations to a connection
table and using unique author ids and unique affiliation ids.

EPrints, unfortunately, neither offers n:m connection tables nor unique author ids out of
the box. The eprintid of the eprint and position of the author in the eprint are not 
sufficient properties to calculate a unique hash for the author - the position is variable.
Author names are neither unique, and coverage of ORCID is not widespread enough to use 
ORCID iD as an author id throughout the whole EPrints repository.

Therefore, the following model was implemented as a compromise
- an affiliation dataset (table) is added to store standardised affiliation data: 
  essentially affiliation_id, organization, city, country
- an affiliation_ids subfield is added to the creator and editor fields. It stores the 
  affiliation ids of the author in sequence, separated by a pipe | character 
- render methods are used to provide the relation between an author and his/her 
  affiliations. They split the sequential affiliation ids and fetch the data from the 
  affiliations dataset.

Advantages:
- the standard EPrints methods can be used, without having to change the core code in p
  perl_lib/EPrints and the field metadata definition for name data.
- flexibility in rendering the affiliation data (e.g. only id and organisation in workflow,
  or full affiliation data in eprint detail page).
- the affiliation dataset can be easily manipulated (edited, deleted) without affecting 
  the core bibliographic metadata

Disadvantages:
- If the source does not provide an affiliation id with the affiliation, the affiliation 
  can not be stored. For example, Scopus does not provide affiliation ids for private 
  addresses.
  In the affiliations code, it was decided not to create a unique affiliation id then. 
- Author matching may be difficult, both due to quality of author data in repository and 
  quality of author and affiliation data in the originating source.


### ScopusAbstract Import Plugin and Script

For these, an API key is required for Scopus (available through the institution's 
subscription to Scopus and https://dev.elsevier.com ). The key must be provided in
cfg.d/z_scopusabstract.pl

The ScopusAbstract Plugin hooks into the Import on the Manage Deposits page and allows to
import one or several Scopus records into the repository via the Scopus Abstract 
Retrieval API (using DOI or Scopus eid). See documentation in 
cfg/plugins/EPrints/Plugin/Import/ScopusAbstract.pm about what is imported.

bin/import_scopus_affiliations is a script to batch update author records with 
affiliations. For more information, perldoc import_scopus_affiliations .


### Background

The code had been developed as part of a project with the International Relations Office 
of University of Zurich for the purpose of evaluating international collaborations. 
It is provided here as is.