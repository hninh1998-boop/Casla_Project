@EndUserText.label: 'zabs_delete_massChange'
define abstract entity zabs_delete_massChange
{
  JobText         : abap.string(0);
  RunInBackground : abap_boolean;
  RunNow          : abap_boolean;
}
