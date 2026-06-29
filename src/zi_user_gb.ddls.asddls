@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Interface - excel Usuário'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: {
  serviceQuality: #X,
  sizeCategory: #S,
  dataClass: #MIXED
}
define root view entity ZI_USER_GB
  as select from ztg_excel_user
  composition [0..*] of ZI_DATA_GB as _XLData
{
  key end_user              as EndUser,
  key file_id               as FileId,
      file_status           as FileStatus,

      attachment            as Attachment,
      @Semantics.mimeType: true
      mimetype              as Mimetype,
      filename              as Filename,

      @Semantics.user.createdBy: true
      local_created_by      as LocalCreatedBy,
      @Semantics.systemDateTime.createdAt: true
      local_created_at      as LocalCreatedAt,
      @Semantics.user.lastChangedBy: true
      local_last_changed_by as LocalLastChangedBy,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at as LocalLastChangedAt,
      @Semantics.systemDateTime.lastChangedAt: true
      last_changed_at       as LastChangedAt,

      case file_status
                 when 'Arquivo não selecionado' then 1
                 when 'Arquivo selecionado'     then 2
                 when 'Arquivo Processado'      then 3
                 else 0
                 end         as Criticality,

      @Semantics.largeObject: {
            mimeType: 'TemplMimetype',
            fileName: 'TemplFilename',
            contentDispositionPreference: #ATTACHMENT }
      templ_content         as TemplContent,
      @Semantics.mimeType: true
      templ_mimetype        as TemplMimetype,
      templ_filename        as TemplFilename,

      _XLData
}
