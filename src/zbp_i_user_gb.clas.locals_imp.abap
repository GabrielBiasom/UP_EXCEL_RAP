CLASS lhc_XLHead DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR XLHead RESULT result.

    METHODS earlynumbering_create FOR NUMBERING
      IMPORTING entities FOR CREATE XLHead.

    METHODS uploadExcelData FOR MODIFY
      IMPORTING keys FOR ACTION XLHead~uploadExcelData RESULT result.

    METHODS FillFileStatus FOR DETERMINE ON MODIFY
      IMPORTING keys FOR XLHead~FillFileStatus.

    METHODS FillSelectedStatus FOR DETERMINE ON MODIFY
      IMPORTING keys FOR XLHead~FillSelectedStatus.

**    METHODS ValidateField FOR VALIDATE ON SAVE
**      IMPORTING keys FOR XLHead~ValidateField.

    METHODS: generate_xl_template
      RETURNING VALUE(rv_content) TYPE ztg_excel_user-templ_content.

ENDCLASS.

CLASS lhc_XLHead IMPLEMENTATION.

  METHOD get_instance_authorizations.
  ENDMETHOD.

  METHOD earlynumbering_create.

    "Número aleatório pra ID
    DATA(lv_user) = cl_abap_context_info=>get_user_technical_name( ).

    LOOP AT entities ASSIGNING FIELD-SYMBOL(<lfs_entities>).
      APPEND CORRESPONDING #( <lfs_entities> ) TO mapped-xlhead
             ASSIGNING FIELD-SYMBOL(<lfs_xlhead>).

      <lfs_xlhead>-EndUser = lv_user.

      IF <lfs_xlhead>-FileId IS INITIAL.
        TRY.
            <lfs_xlhead>-FileId = cl_system_uuid=>create_uuid_x16_static( ).
          CATCH cx_uuid_error.

        ENDTRY.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.

  METHOD uploadExcelData.

    DATA: lt_rows         TYPE STANDARD TABLE OF string,
          lv_content      TYPE string,
          lo_table_descr  TYPE REF TO cl_abap_tabledescr,
          lo_struct_descr TYPE REF TO cl_abap_structdescr,
          lt_excel        TYPE STANDARD TABLE OF zbp_i_user_gb=>gty_gr_xl,
          lt_data         TYPE TABLE FOR CREATE zi_user_gb\_XLData,
          lv_index        TYPE sy-index.

    """""""""""" INICIO LER O ARQUIVO
    FIELD-SYMBOLS: <lfs_col_header> TYPE string.

    DATA(lv_user) = cl_abap_context_info=>get_user_technical_name( ).

    READ ENTITIES OF zi_user_gb IN LOCAL MODE
      ENTITY XLHead
      ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_file_entity).

    DATA(lv_attachment) = lt_file_entity[ 1 ]-attachment.
    CHECK lv_attachment IS NOT INITIAL.

    "Move dados do excel pra tabela interna
    DATA(lo_xlsx) = xco_cp_xlsx=>document->for_file_content( iv_file_content = lv_attachment )->read_access( ).

    DATA(lo_worksheet) = lo_xlsx->get_workbook( )->worksheet->at_position( 1 ).

    DATA(lo_selection_pattern) = xco_cp_xlsx_selection=>pattern_builder->simple_from_to( )->get_pattern( ).

    DATA(lo_execute) = lo_worksheet->select( lo_selection_pattern )->row_stream( )->operation->write_to( REF #( lt_excel ) ).

    lo_execute->set_value_transformation( xco_cp_xlsx_read_access=>value_transformation->string_value )->if_xco_xlsx_ra_operation~execute( ).

    " Pega o numero de colunas do arquivo para validação
    TRY.
        lo_table_descr ?= cl_abap_tabledescr=>describe_by_data( p_data = lt_excel ).
        lo_struct_descr ?= lo_table_descr->get_table_line_type( ).
        DATA(lv_no_of_cols) = lines( lo_struct_descr->components ).
      CATCH cx_sy_move_cast_error.

    ENDTRY.
    """""""""""" FIM LER O ARQUIVO

    """""""""""" INICIO Validar o formato do arquivo
    " Validar o cabeçalho do arquivo - deve conter exatamente as colunas:
    " PO NUMBER, PO ITEM, GR QUANTITY, UNIT OF MEASURE, SITE ID, HEADER TEXT (nessa ordem)
    DATA(ls_excel) = VALUE #( lt_excel[ 1 ] OPTIONAL ).
    IF ls_excel IS NOT INITIAL.
      DO lv_no_of_cols TIMES.
        lv_index = sy-index.

        ASSIGN COMPONENT lv_index OF STRUCTURE ls_excel TO <lfs_col_header>.
        CHECK <lfs_col_header> IS ASSIGNED.

        DATA(lv_value) = to_upper( <lfs_col_header> ).
        DATA(lv_has_error) = abap_false.

        CASE lv_index.
          WHEN 1.
            lv_has_error = COND #( WHEN lv_value <> 'PO NUMBER' THEN abap_true ELSE lv_has_error ).
          WHEN 2.
            lv_has_error = COND #( WHEN lv_value <> 'PO ITEM' THEN abap_true ELSE lv_has_error ).
          WHEN 3.
            lv_has_error = COND #( WHEN lv_value <> 'GR QUANTITY' THEN abap_true ELSE lv_has_error ).
          WHEN 4.
            lv_has_error = COND #( WHEN lv_value <> 'UNIT OF MEASURE' THEN abap_true ELSE lv_has_error ).
          WHEN 5.
            lv_has_error = COND #( WHEN lv_value <> 'SITE ID' THEN abap_true ELSE lv_has_error ).
          WHEN 6.
            lv_has_error = COND #( WHEN lv_value <> 'HEADER TEXT' THEN abap_true ELSE lv_has_error ).
          WHEN 9. " Mais que 7 colunas (error)
            lv_has_error = abap_true.
        ENDCASE.

        IF lv_has_error = abap_true.
          APPEND VALUE #( %tky = lt_file_entity[ 1 ]-%tky ) TO failed-xlhead.

          APPEND VALUE #(
            %tky = lt_file_entity[ 1 ]-%tky
            %msg = new_message_with_text(
              severity = if_abap_behv_message=>severity-error
              text     = 'Mensagem formato errado!' )
          ) TO reported-XLHead.

          UNASSIGN <lfs_col_header>.
          EXIT.
        ENDIF.

        UNASSIGN <lfs_col_header>.
      ENDDO.
    ENDIF.

    CHECK lv_has_error = abap_false.

    DELETE lt_excel INDEX 1.
    DELETE lt_excel WHERE po_number IS INITIAL.

    " preencher Line ID e Line Number pra cada entrada no excel
    TRY.
        DATA(lv_line_id) = cl_system_uuid=>create_uuid_x16_static( ).
      CATCH cx_uuid_error.
    ENDTRY.
    """""""""""" FIM Validar o formato do arquivo

    """""""""""" INICIO Tratamento de dados
    LOOP AT lt_excel ASSIGNING FIELD-SYMBOL(<lfs_excel>).
      <lfs_excel>-line_id     = lv_line_id.
      <lfs_excel>-line_number = sy-tabix.
    ENDLOOP.

    "prepara 'Data' para entidade filha (XLData)
    lt_data = VALUE #(
      ( %cid_ref = keys[ 1 ]-%cid_ref
        %is_draft = keys[ 1 ]-%is_draft
        Enduser   = keys[ 1 ]-EndUser
        FileId    = keys[ 1 ]-FileId
        %target   = VALUE #(
          FOR lwa_excel IN lt_excel (
            %cid = |{ lwa_excel-po_number }_{ lwa_excel-po_item }_{ lwa_excel-site_id }|
              %is_draft = keys[ 1 ]-%is_draft
               %data = VALUE #(
                          EndUser       = keys[ 1 ]-EndUser
                          FileId        = keys[ 1 ]-FileId
                          LineId        = lwa_excel-line_id
                          LineNumber    = lwa_excel-line_number
                          PoNumber      = lwa_excel-po_number
                          PoItem        = lwa_excel-po_item
                          GrQuantity    = lwa_excel-gr_quantity
                          UnitOfMeasure = lwa_excel-unit_of_measure
                          SiteId        = lwa_excel-site_id
                          HeaderText    = lwa_excel-header_text
                )

                %control = VALUE #(
                  EndUser       = if_abap_behv=>mk-on
                  FileId        = if_abap_behv=>mk-on
                  LineNumber    = if_abap_behv=>mk-on
                  LineId        = if_abap_behv=>mk-on
                  PoNumber      = if_abap_behv=>mk-on
                  PoItem        = if_abap_behv=>mk-on
                  GrQuantity    = if_abap_behv=>mk-on
                  UnitOfMeasure = if_abap_behv=>mk-on
                  SiteId        = if_abap_behv=>mk-on
                  HeaderText    = if_abap_behv=>mk-on
                )
           )
         )
       )
    ).

    """""""""""" FIM Tratamento de dados

    """""""""""" INICIO modificar tabelas
    "deleta entradas existentes do usuario, caso existam, para evitar duplicidade de dados
    READ ENTITIES OF zi_user_gb IN LOCAL MODE
      ENTITY XLHead BY \_XLData
      ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_existing_XLData).

    IF lt_existing_XLData IS NOT INITIAL.
      MODIFY ENTITIES OF zi_user_gb IN LOCAL MODE
        ENTITY XLData DELETE FROM VALUE #(
          FOR lwa_data IN lt_existing_XLData (
            %key      = lwa_data-%key
            %is_draft = lwa_data-%is_draft
          )
        )
        MAPPED DATA(lt_del_mapped)
        REPORTED DATA(lt_del_reported)
        FAILED DATA(lt_del_failed).
    ENDIF.

    "adiciona novas entradas para XLData (association)
    MODIFY ENTITIES OF zi_user_gb IN LOCAL MODE
        ENTITY XLHead CREATE BY \_XLData
        AUTO FILL CID WITH lt_data.

    "MODIFY Status
    MODIFY ENTITIES OF zi_user_gb IN LOCAL MODE
        ENTITY XLHead
        UPDATE FROM VALUE #(
          (
            %tky = lt_file_entity[ 1 ]-%tky
            fileStatus = 'Arquivo Processado'
            %control-FileStatus = if_abap_behv=>mk-on
          )
        )
        MAPPED DATA(lt_upd_mapped)
        FAILED DATA(lt_upd_failed)
        REPORTED DATA(lt_upd_reported).

    "Ler entradas 'upadas'
    READ ENTITIES OF zi_user_gb IN LOCAL MODE
     ENTITY XLHead ALL FIELDS WITH CORRESPONDING #( keys )
     RESULT DATA(lt_updated_xlhead).

    "Envia Status de volta pro Front
    result = VALUE #(
       FOR lwa_upd_head IN lt_updated_xlhead (
              %tky   = lwa_upd_head-%tky
              %param = lwa_upd_head
    ) ).
    """""""""""" FIM modificar tabelas
  ENDMETHOD.

  METHOD FillFileStatus.

    DATA: ls_template TYPE ztg_excel_user.

    "ler os dados que serão modificados
    READ ENTITIES OF zi_user_gb IN LOCAL MODE
      ENTITY XLHead FIELDS ( EndUser FileStatus )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_user).

    " Template excel para usuário
    ls_template-templ_content  = generate_xl_template( ).
    ls_template-templ_mimetype = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'.
    ls_template-templ_filename = 'Modelo_excel.xlsx'.

    "Atualiza o Status do arquivo para 'Não selecionado' caso o usuário tenha desmarcado o arquivo (Attachment vazio)
    LOOP AT lt_user INTO DATA(ls_user).
      MODIFY ENTITIES OF zi_user_gb IN LOCAL MODE
        ENTITY XLHead
        UPDATE FIELDS ( FileStatus templcontent templmimetype templfilename  )
        WITH VALUE #(
          (
            %tky = ls_user-%tky
            %data-FileStatus = 'Arquivo não selecionado'
            %data-templcontent = ls_template-templ_content
            %data-templmimetype = ls_template-templ_mimetype
            %data-templfilename = ls_template-templ_filename

            %control-FileStatus = if_abap_behv=>mk-on
            %control-templcontent  = if_abap_behv=>mk-on
            %control-templmimetype = if_abap_behv=>mk-on
            %control-templfilename = if_abap_behv=>mk-on
          )
        ).
    ENDLOOP.

  ENDMETHOD.

  METHOD FillSelectedStatus.

    "Trocar Status

    "Deleta XLData existente, caso exista, para evitar que dados de um arquivo selecionado anteriormente
    "permaneçam na tela caso o usuário desmarque o arquivo (Attachment vazio)
    READ ENTITIES OF zi_user_gb IN LOCAL MODE
      ENTITY XLHead BY \_XLData
      ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_existing_XLData).

    IF lt_existing_xldata IS NOT INITIAL.
      MODIFY ENTITIES OF zi_user_gb IN LOCAL MODE
        ENTITY XLData DELETE FROM VALUE #(
          FOR lwa_data IN lt_existing_XLData (
            %key      = lwa_data-%key
            %is_draft = lwa_data-%is_draft
          ) ).
*      MAPPED DATA(lt_del_mapped)
*      REPORTED DATA(lt_del_reported)
*      FAILED DATA(lt_del_failed).
    ENDIF.

    "Ler XL_Head para verificar qual arquivo foi desmarcado (Attachment vazio)
    "e atualizar o status do arquivo para 'Não selecionado'
    READ ENTITIES OF zi_user_gb IN LOCAL MODE
      ENTITY XLHead ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_xlhead).

    "Atualiza o Status do arquivo
    LOOP AT lt_xlhead INTO DATA(ls_xlhead).
      MODIFY ENTITIES OF zi_user_gb IN LOCAL MODE
        ENTITY XLHead
        UPDATE FIELDS ( FileStatus )
        WITH VALUE #(
          (
            %tky = ls_xlhead-%tky
            %data-FileStatus = COND #(
                                      WHEN ls_xlhead-Attachment IS INITIAL
                                      THEN 'Arquivo não selecionado'
                                      ELSE 'Arquivo selecionado'
                                     )
            %control-FileStatus = if_abap_behv=>mk-on
          )
        ).
    ENDLOOP.

  ENDMETHOD.

*  METHOD ValidateField.
*
*    READ ENTITIES OF zi_gb_user IN LOCAL MODE
*       ENTITY XLHead ALL FIELDS WITH CORRESPONDING #( keys )
*       RESULT DATA(lt_xlhead).
*
*    IF lt_xlhead IS NOT INITIAL.
*      IF lt_xlhead[ 1 ]-Attachment IS INITIAL.
*
*        APPEND VALUE #( %tky = lt_xlhead[ 1 ]-%tky ) TO failed-XLHead.
*
*        APPEND VALUE #(
*          %tky = lt_xlhead[ 1 ]-%tky
*          %msg = new_message_with_text(
*            severity = if_abap_behv_message=>severity-error
*            text     = 'Para salvar, selecione um arquivo Excel!' )
*        ) TO reported-XLHead.
*
*      ENDIF.
*    ENDIF.
*  ENDMETHOD.

  METHOD generate_xl_template.

    "Gera o template excel para download local pelo usuário
    TYPES: BEGIN OF lty_template_exist,
             templ_content  TYPE ztg_excel_user-templ_content,
             templ_mimetype TYPE ztg_excel_user-templ_mimetype,
             templ_filename TYPE ztg_excel_user-templ_filename,
           END OF lty_template_exist.

    DATA: ls_template_exist TYPE lty_template_exist.

    "Verifica se ja existe Template para a entidade
    SELECT SINGLE templ_content, templ_mimetype, templ_filename
      FROM ztg_excel_user
      WHERE templ_filename IS NOT INITIAL
      INTO @ls_template_exist.

    IF sy-subrc IS NOT INITIAL.
      "Agora verifica na tabela Draft
      SELECT SINGLE templcontent, templmimetype, templfilename
        FROM ztg_excel_userd
        WHERE templfilename IS NOT INITIAL
        INTO @ls_template_exist.
    ENDIF.

    IF ls_template_exist IS NOT INITIAL.
      rv_content = ls_template_exist-templ_content.
      RETURN.
    ENDIF.

    "Configura o arquivo
    TRY.

        "Classe disponibilizada pela SAP para manipulação de arquivos Excel (XLSX), nesse caso, criar.
        DATA(lo_xlsx) = xco_cp_xlsx=>document->empty( )->write_access( ).

        "Add Sheet do modelo
        DATA(lo_worksheet) = lo_xlsx->get_workbook( )->worksheet->at_position( 1 ).
        lo_worksheet->set_name( iv_name = 'Modelo' ).

        DATA(lo_cursor) = lo_worksheet->cursor(
                              io_column = xco_cp_xlsx=>coordinate->for_alphabetic_value( 'A' )
                              io_row    = xco_cp_xlsx=>coordinate->for_numeric_value( 1 ) ).

        "Cabeçalho
        lo_cursor->get_cell( )->value->write_from( 'PO Number' ).

        lo_cursor->move_right( )->get_cell( )->value->write_from( 'PO Item' ).

        lo_cursor->move_right( )->get_cell( )->value->write_from( 'GR Quantity' ).

        lo_cursor->move_right( )->get_cell( )->value->write_from( 'Unit of Measure' ).

        lo_cursor->move_right( )->get_cell( )->value->write_from( 'Site ID' ).

        lo_cursor->move_right( )->get_cell( )->value->write_from( 'Header Text' ).

        DATA(lv_content) = lo_xlsx->get_file_content( ).
      CATCH cx_root.
    ENDTRY.

    rv_content = lv_content.

  ENDMETHOD.

ENDCLASS.
