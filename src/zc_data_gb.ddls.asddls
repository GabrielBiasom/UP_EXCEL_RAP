@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'CONSUMPTION CAMPOS UPLOAD EXCEL'
@Metadata.ignorePropagatedAnnotations: true
@Metadata.allowExtensions: true
define view entity ZC_DATA_GB
  as projection on ZI_DATA_GB
{
  key EndUser,
  key FileId,
  key LineId,
  key LineNumber,
      PoNumber,
      PoItem,
      GrQuantity,
      UnitOfMeasure,
      SiteId,
      HeaderText,
      /* Associations */
      _XLUser : redirected to parent ZC_USER_GB
}
