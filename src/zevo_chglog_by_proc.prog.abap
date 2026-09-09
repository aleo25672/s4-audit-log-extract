REPORT zevo_chglog_by_proc MESSAGE-ID zevo_chglog.

DATA gv_date TYPE cdhdr-udate.
DATA gv_time TYPE cdhdr-utime.
DATA gv_user TYPE cdhdr-username.
DATA gv_objectid TYPE cdhdr-objectid.

SELECTION-SCREEN BEGIN OF BLOCK b_process WITH FRAME TITLE text-t01.
  PARAMETERS p_proc TYPE zevo_chglog_proc-process AS LISTBOX VISIBLE LENGTH 45
    OBLIGATORY.
SELECTION-SCREEN END OF BLOCK b_process.

SELECTION-SCREEN BEGIN OF BLOCK b_period WITH FRAME TITLE text-t02.
  SELECTION-SCREEN COMMENT /1(79) gv_tipd1.
  SELECTION-SCREEN COMMENT /1(79) gv_tipd2.
  SELECT-OPTIONS s_date FOR gv_date OBLIGATORY.
  SELECT-OPTIONS s_time FOR gv_time.
SELECTION-SCREEN END OF BLOCK b_period.

SELECTION-SCREEN BEGIN OF BLOCK b_limit WITH FRAME TITLE text-t03.
  SELECTION-SCREEN COMMENT /1(79) gv_tipr1.
  SELECTION-SCREEN COMMENT /1(79) gv_tipr2.
  PARAMETERS p_max TYPE i DEFAULT 10000.
SELECTION-SCREEN END OF BLOCK b_limit.

SELECTION-SCREEN BEGIN OF BLOCK b_output WITH FRAME TITLE text-t05.
  PARAMETERS p_alv RADIOBUTTON GROUP out DEFAULT 'X' USER-COMMAND output.
  PARAMETERS p_local RADIOBUTTON GROUP out.
  PARAMETERS p_server RADIOBUTTON GROUP out.
  PARAMETERS p_logfil TYPE filename-fileintern MODIF ID srv.
  PARAMETERS p_fparm TYPE c LENGTH 60 MODIF ID srv.
SELECTION-SCREEN END OF BLOCK b_output.

SELECTION-SCREEN BEGIN OF BLOCK b_filter WITH FRAME TITLE text-t04.
  SELECT-OPTIONS s_user FOR gv_user.
  SELECT-OPTIONS s_objid FOR gv_objectid.
SELECTION-SCREEN END OF BLOCK b_filter.

INITIALIZATION.
  gv_tipd1 = 'Tip: Prefer a narrow date range (for example, one day or one week).'.
  gv_tipd2 = 'Wider ranges read more change history and require more runtime and memory.'.
  gv_tipr1 = 'Tip: Max rows limits field-level ALV lines. Default: 10,000.'.
  gv_tipr2 = 'Raise it for larger extracts, or set 0 for no limit. A warning marks truncation.'.
  p_fparm = |s4_changelog_{ sy-datum }_{ sy-uzeit }|.

  APPEND VALUE #( sign = 'I' option = 'EQ' low = sy-datum ) TO s_date.
  APPEND VALUE #( sign = 'I' option = 'BT' low = '000000' high = '235959' ) TO s_time.

AT SELECTION-SCREEN OUTPUT.
  PERFORM set_process_values.
  LOOP AT SCREEN.
    IF screen-group1 = 'SRV'.
      screen-active = xsdbool( p_server = abap_true ).
      MODIFY SCREEN.
    ENDIF.
  ENDLOOP.

AT SELECTION-SCREEN.
  IF p_max < 0.
    MESSAGE e000.
  ENDIF.
  IF p_server = abap_true AND p_logfil IS INITIAL.
    MESSAGE 'Enter a logical filename configured in transaction FILE' TYPE 'E'.
  ENDIF.

START-OF-SELECTION.
  PERFORM execute_report.


FORM set_process_values.
  TYPES:
    BEGIN OF ty_process,
      process TYPE zevo_chglog_proc-process,
      descr   TYPE zevo_chglog_proc-descr,
    END OF ty_process.

  DATA lt_values TYPE vrm_values.
  DATA lt_processes TYPE STANDARD TABLE OF ty_process WITH EMPTY KEY.

  SELECT process, descr
    FROM zevo_chglog_proc
    WHERE active = @abap_true
    ORDER BY seq, process
    INTO TABLE @lt_processes.

  LOOP AT lt_processes ASSIGNING FIELD-SYMBOL(<ls_process>).
    APPEND VALUE #(
      key = <ls_process>-process
      text = |{ <ls_process>-process } - { <ls_process>-descr }| ) TO lt_values.
  ENDLOOP.

  IF p_proc IS INITIAL.
    READ TABLE lt_processes INDEX 1 ASSIGNING <ls_process>.
    IF sy-subrc = 0.
      p_proc = <ls_process>-process.
    ENDIF.
  ENDIF.

  CALL FUNCTION 'VRM_SET_VALUES'
    EXPORTING
      id              = 'P_PROC'
      values          = lt_values
    EXCEPTIONS
      id_illegal_name = 1
      OTHERS          = 2.
ENDFORM.


FORM execute_report.
  DATA lo_reader TYPE REF TO zcl_evo_chglog_reader.
  DATA lt_result TYPE zcl_evo_chglog_reader=>tt_result.
  DATA lv_truncated TYPE abap_bool.
  DATA lv_error TYPE string.
  DATA lo_alv TYPE REF TO cl_salv_table.
  DATA lo_columns TYPE REF TO cl_salv_columns_table.
  DATA lv_title TYPE lvc_title.
  DATA lo_exporter TYPE REF TO zcl_evo_chglog_exporter.
  DATA lt_csv TYPE zcl_evo_chglog_exporter=>tt_csv.
  DATA lv_file_name TYPE string.
  DATA lv_cancelled TYPE abap_bool.
  DATA lv_default_name TYPE string.
  DATA lv_file_parameter TYPE zcl_evo_chglog_exporter=>ty_file_parameter.
  DATA lt_date TYPE zcl_evo_chglog_reader=>ty_date_range.
  DATA lt_time TYPE zcl_evo_chglog_reader=>ty_time_range.
  DATA lt_user TYPE zcl_evo_chglog_reader=>ty_user_range.
  DATA lt_objectid TYPE zcl_evo_chglog_reader=>ty_objectid_range.
  DATA lv_process TYPE zcl_evo_chglog_reader=>ty_process.

  lv_process = p_proc.
  lt_date = CORRESPONDING #( s_date[] ).
  lt_time = CORRESPONDING #( s_time[] ).
  lt_user = CORRESPONDING #( s_user[] ).
  lt_objectid = CORRESPONDING #( s_objid[] ).

  CREATE OBJECT lo_reader.
  lo_reader->read(
    EXPORTING
      iv_process   = lv_process
      it_date      = lt_date
      it_time      = lt_time
      it_user      = lt_user
      it_objectid  = lt_objectid
      iv_max_rows  = p_max
    IMPORTING
      et_result    = lt_result
      ev_truncated = lv_truncated
      ev_error     = lv_error ).

  IF lv_error IS NOT INITIAL.
    MESSAGE lv_error TYPE 'E'.
  ENDIF.
  IF lt_result IS INITIAL.
    MESSAGE s003.
    RETURN.
  ENDIF.
  IF lv_truncated = abap_true.
    MESSAGE s002 WITH p_max.
  ENDIF.

  IF p_local = abap_true OR p_server = abap_true.
    CREATE OBJECT lo_exporter.
    lt_csv = lo_exporter->to_csv( lt_result ).
    lv_default_name = |s4_changelog_{ p_proc }_{ sy-datum }_{ sy-uzeit }.csv|.

    IF p_local = abap_true.
      lo_exporter->download_local(
        EXPORTING
          it_csv          = lt_csv
          iv_default_name = lv_default_name
        IMPORTING
          ev_file_name    = lv_file_name
          ev_cancelled    = lv_cancelled
          ev_error        = lv_error ).
      IF lv_cancelled = abap_true.
        MESSAGE 'Local download cancelled' TYPE 'S'.
        RETURN.
      ENDIF.
    ELSE.
      lv_file_parameter = p_fparm.
      lo_exporter->write_server(
        EXPORTING
          it_csv              = lt_csv
          iv_logical_filename = p_logfil
          iv_parameter_1      = lv_file_parameter
        IMPORTING
          ev_file_name        = lv_file_name
          ev_error            = lv_error ).
    ENDIF.

    IF lv_error IS NOT INITIAL.
      MESSAGE lv_error TYPE 'E'.
    ENDIF.
    MESSAGE |CSV file written: { lv_file_name }| TYPE 'S'.
    RETURN.
  ENDIF.

  TRY.
      cl_salv_table=>factory(
        IMPORTING
          r_salv_table = lo_alv
        CHANGING
          t_table      = lt_result ).

      lo_alv->get_functions( )->set_all( abap_true ).
      lo_columns = lo_alv->get_columns( ).
      lo_columns->set_optimize( abap_true ).
      PERFORM set_column_texts USING lo_columns.

      lv_title = |S/4 Change Log: { p_proc } ({ lines( lt_result ) } rows)|.
      lo_alv->get_display_settings( )->set_list_header( lv_title ).
      lo_alv->get_display_settings( )->set_striped_pattern( abap_true ).
      lo_alv->display( ).
    CATCH cx_salv_msg INTO DATA(lx_salv).
      MESSAGE lx_salv->get_text( ) TYPE 'E'.
  ENDTRY.
ENDFORM.


FORM set_column_texts USING io_columns TYPE REF TO cl_salv_columns_table.
  DATA lo_column TYPE REF TO cl_salv_column_table.

  TRY.
      lo_column ?= io_columns->get_column( 'PROCESS' ).
      lo_column->set_long_text( 'Business Process' ).
      lo_column->set_medium_text( 'Process' ).
      lo_column->set_short_text( 'Process' ).

      lo_column ?= io_columns->get_column( 'OBJECTCLAS' ).
      lo_column->set_long_text( 'Change Document Object Class' ).
      lo_column->set_medium_text( 'Object Class' ).
      lo_column->set_short_text( 'Obj.Class' ).

      lo_column ?= io_columns->get_column( 'OBJDESCR' ).
      lo_column->set_long_text( 'Business Object Description' ).
      lo_column->set_medium_text( 'Object Description' ).
      lo_column->set_short_text( 'Object' ).

      lo_column ?= io_columns->get_column( 'OBJECTID' ).
      lo_column->set_long_text( 'Change Document Object ID' ).
      lo_column->set_medium_text( 'Object ID' ).
      lo_column->set_short_text( 'Object ID' ).

      lo_column ?= io_columns->get_column( 'CHANGENR' ).
      lo_column->set_long_text( 'Change Document Number' ).
      lo_column->set_medium_text( 'Change Number' ).
      lo_column->set_short_text( 'Change No.' ).

      lo_column ?= io_columns->get_column( 'UDATE' ).
      lo_column->set_long_text( 'Change Date' ).
      lo_column->set_medium_text( 'Change Date' ).
      lo_column->set_short_text( 'Date' ).

      lo_column ?= io_columns->get_column( 'UTIME' ).
      lo_column->set_long_text( 'Change Time' ).
      lo_column->set_medium_text( 'Change Time' ).
      lo_column->set_short_text( 'Time' ).

      lo_column ?= io_columns->get_column( 'USERNAME' ).
      lo_column->set_long_text( 'Changed By' ).
      lo_column->set_medium_text( 'Changed By' ).
      lo_column->set_short_text( 'User' ).

      lo_column ?= io_columns->get_column( 'TCODE' ).
      lo_column->set_long_text( 'Transaction Code' ).
      lo_column->set_medium_text( 'Transaction' ).
      lo_column->set_short_text( 'TCode' ).

      lo_column ?= io_columns->get_column( 'CHNGIND' ).
      lo_column->set_long_text( 'Change Indicator' ).
      lo_column->set_medium_text( 'Change Indicator' ).
      lo_column->set_short_text( 'Change' ).

      lo_column ?= io_columns->get_column( 'TABNAME' ).
      lo_column->set_long_text( 'Changed Table' ).
      lo_column->set_medium_text( 'Table' ).
      lo_column->set_short_text( 'Table' ).

      lo_column ?= io_columns->get_column( 'TABKEY' ).
      lo_column->set_long_text( 'Changed Table Key' ).
      lo_column->set_medium_text( 'Table Key' ).
      lo_column->set_short_text( 'Table Key' ).

      lo_column ?= io_columns->get_column( 'FNAME' ).
      lo_column->set_long_text( 'Changed Field' ).
      lo_column->set_medium_text( 'Field' ).
      lo_column->set_short_text( 'Field' ).

      lo_column ?= io_columns->get_column( 'VALUE_OLD' ).
      lo_column->set_long_text( 'Old Value' ).
      lo_column->set_medium_text( 'Old Value' ).
      lo_column->set_short_text( 'Old Value' ).

      lo_column ?= io_columns->get_column( 'VALUE_NEW' ).
      lo_column->set_long_text( 'New Value' ).
      lo_column->set_medium_text( 'New Value' ).
      lo_column->set_short_text( 'New Value' ).
    CATCH cx_salv_not_found.
      " The report remains usable if a release omits an optional column.
  ENDTRY.
ENDFORM.
