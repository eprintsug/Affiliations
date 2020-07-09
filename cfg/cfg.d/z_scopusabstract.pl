# UZH CHANGE ZORA-736 2019/08/23/mb Scopus Abstract Retrieval API
$c->{plugins}->{"Import::ScopusAbstract"}->{params}->{api_url} = 'https://api.elsevier.com/content/abstract';
# API Key 
$c->{plugins}->{"Import::ScopusAbstract"}->{params}->{developer_id} = "{add your Scopus API key here}";
$c->{plugins}->{"Import::ScopusAbstract"}->{params}->{use_prefix} = 0;
$c->{plugins}->{"Import::ScopusAbstract"}->{params}->{doi_field} = 'doi';
$c->{plugins}->{"Import::ScopusAbstract"}->{params}->{org_exceptions} = [
  'et al',
  'collaboration',
  'collaborators',
  'consortium',
  'group',
  'ieee',
  'investigators',
  'network',
  'society',
  'study',
];
