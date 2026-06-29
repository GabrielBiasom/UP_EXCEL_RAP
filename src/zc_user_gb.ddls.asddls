@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'CONSUMPTION CAMPOS UPLOAD EXCEL'
@Metadata.ignorePropagatedAnnotations: true
@Metadata.allowExtensions: true
define root view entity ZC_USER_GB
  provider contract transactional_query
  as projection on ZI_USER_GB
{
  key EndUser,
  key FileId,
      FileStatus,

      @Semantics.largeObject: {
        mimeType: 'Mimetype',
        fileName: 'Filename',
        acceptableMimeTypes: [
          'application/vnd.ms-excel',
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
        ],
        contentDispositionPreference: #INLINE
      }
      Attachment,
      Mimetype,
      Filename,

      LocalCreatedBy,
      LocalCreatedAt,
      LocalLastChangedBy,
      LocalLastChangedAt,
      LastChangedAt,

      Criticality,

      @Semantics.largeObject: {
            mimeType: 'TemplMimetype',
            fileName: 'TemplFilename',
            contentDispositionPreference: #ATTACHMENT }
      TemplContent,
      TemplMimetype,
      TemplFilename,

      /* Associations */
      _XLData : redirected to composition child ZC_DATA_GB
}
