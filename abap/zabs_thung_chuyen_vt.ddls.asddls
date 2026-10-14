@EndUserText.label: 'Abs.Ent. - Chuyển vị trí thùng mẫu'
define abstract entity zabs_thung_chuyen_vt
{
  @EndUserText.label: 'Storage Location'
  @Consumption.valueHelpDefinition: [{ entity: { name: 'I_StorageLocationStdVH', element: 'StorageLocation' },
                                           additionalBinding: [{ element: 'Plant', localConstant: '6731', usage: #FILTER }] }]
  StorageLocation : lgort_d;

}
