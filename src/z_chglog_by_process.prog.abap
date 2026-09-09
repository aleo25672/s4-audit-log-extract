REPORT z_chglog_by_process MESSAGE-ID zchglog.

DATA gv_date TYPE cdhdr-udate.
DATA gv_time TYPE cdhdr-utime.
DATA gv_user TYPE cdhdr-username.
DATA gv_objectid TYPE cdhdr-objectid.

SELECTION-SCREEN BEGIN OF BLOCK b_process WITH FRAME TITLE text-t01.
  PARAMETERS p_proc TYPE c LENGTH 3 AS LISTBOX VISIBLE LENGTH 30
    OBLIGATORY DEFAULT 'P2P'.
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

SELECTION-SCREEN BEGIN OF BLOCK b_filter WITH FRAME TITLE text-t04.
  SELECT-OPTIONS s_user FOR gv_user.
  SELECT-OPTIONS s_objid FOR gv_objectid.
SELECTION-SCREEN END OF BLOCK b_filter.

INITIALIZATION.
  gv_tipd1 = 'Tip: Prefer a narrow date range (for example, one day or one week).'.
  gv_tipd2 = 'Wider ranges read more change history and require more runtime and memory.'.
  gv_tipr1 = 'Tip: Max rows limits field-level ALV lines. Default: 10,000.'.
  gv_tipr2 = 'Raise it for larger extracts, or set 0 for no limit. A warning marks truncation.'.

  APPEND VALUE #( sign = 'I' option = 'EQ' low = sy-datum ) TO s_date.
  APPEND VALUE #( sign = 'I' option = 'BT' low = '000000' high = '235959' ) TO s_time.

AT SELECTION-SCREEN OUTPUT.
  PERFORM set_process_values.

AT SELECTION-SCREEN.
  IF p_max < 0.
    MESSAGE e000.
  ENDIF.

START-OF-SELECTION.
  PERFORM execute_report.


FORM set_process_values.
  DATA lt_values TYPE vrm_values.

  lt_values = VALUE #(
    ( key = 'P2P' text = 'P2P - Sourcing to Payment' )
    ( key = 'O2C' text = 'O2C - Order to Cash' )
    ( key = 'R2R' text = 'R2R - Record to Report' ) ).

  CALL FUNCTION 'VRM_SET_VALUES'
    EXPORTING
      id              = 'P_PROC'
      values          = lt_values
    EXCEPTIONS
      id_illegal_name = 1
      OTHERS          = 2.
ENDFORM.


FORM execute_report.
  DATA lo_reader TYPE REF TO zcl_chglog_reader.
  DATA lt_result TYPE zcl_chglog_reader=>tt_result.
  DATA lv_truncated TYPE abap_bool.
  DATA lv_error TYPE string.
  DATA lo_alv TYPE REF TO cl_salv_table.
  DATA lo_columns TYPE REF TO cl_salv_columns_table.
  DATA lv_title TYPE lvc_title.
  DATA lt_date TYPE zcl_chglog_reader=>ty_date_range.
  DATA lt_time TYPE zcl_chglog_reader=>ty_time_range.
  DATA lt_user TYPE zcl_chglog_reader=>ty_user_range.
  DATA lt_objectid TYPE zcl_chglog_reader=>ty_objectid_range.

  lt_date = CORRESPONDING #( s_date[] ).
  lt_time = CORRESPONDING #( s_time[] ).
  lt_user = CORRESPONDING #( s_user[] ).
  lt_objectid = CORRESPONDING #( s_objid[] ).

  CREATE OBJECT lo_reader.
  lo_reader->read(
    EXPORTING
      iv_process   = CONV #( p_proc )
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
      lo_column->set_short_text( 'Description' ).

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
