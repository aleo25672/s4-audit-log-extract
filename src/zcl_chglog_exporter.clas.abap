CLASS zcl_chglog_exporter DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES tt_csv TYPE STANDARD TABLE OF string WITH EMPTY KEY.
    TYPES ty_file_parameter TYPE c LENGTH 60.

    METHODS to_csv
      IMPORTING
        it_result     TYPE zcl_chglog_reader=>tt_result
      RETURNING
        VALUE(rt_csv) TYPE tt_csv.

    METHODS download_local
      IMPORTING
        it_csv          TYPE tt_csv
        iv_default_name TYPE string
      EXPORTING
        ev_file_name    TYPE string
        ev_cancelled    TYPE abap_bool
        ev_error        TYPE string.

    METHODS write_server
      IMPORTING
        it_csv              TYPE tt_csv
        iv_logical_filename TYPE filename-fileintern
        iv_parameter_1      TYPE ty_file_parameter OPTIONAL
      EXPORTING
        ev_file_name        TYPE string
        ev_error            TYPE string.

  PRIVATE SECTION.
    METHODS quote
      IMPORTING
        iv_value        TYPE any
      RETURNING
        VALUE(rv_value) TYPE string.
ENDCLASS.


CLASS zcl_chglog_exporter IMPLEMENTATION.
  METHOD quote.
    rv_value = |{ iv_value }|.
    REPLACE ALL OCCURRENCES OF '"' IN rv_value WITH '""'.
    rv_value = '"' && rv_value && '"'.
  ENDMETHOD.

  METHOD to_csv.
    APPEND
      '"Process","Object Class","Object Description","Object ID","Change Number",'
      && '"Change Date","Change Time","Username","Transaction","Change Indicator",'
      && '"Table","Table Key","Field","Old Value","New Value"'
      TO rt_csv.

    LOOP AT it_result ASSIGNING FIELD-SYMBOL(<ls_result>).
      APPEND
        quote( <ls_result>-process ) && ',' &&
        quote( <ls_result>-objectclas ) && ',' &&
        quote( <ls_result>-objdescr ) && ',' &&
        quote( <ls_result>-objectid ) && ',' &&
        quote( <ls_result>-changenr ) && ',' &&
        quote( <ls_result>-udate ) && ',' &&
        quote( <ls_result>-utime ) && ',' &&
        quote( <ls_result>-username ) && ',' &&
        quote( <ls_result>-tcode ) && ',' &&
        quote( <ls_result>-chngind ) && ',' &&
        quote( <ls_result>-tabname ) && ',' &&
        quote( <ls_result>-tabkey ) && ',' &&
        quote( <ls_result>-fname ) && ',' &&
        quote( <ls_result>-value_old ) && ',' &&
        quote( <ls_result>-value_new )
        TO rt_csv.
    ENDLOOP.
  ENDMETHOD.

  METHOD download_local.
    DATA lv_filename TYPE string.
    DATA lv_path TYPE string.
    DATA lv_fullpath TYPE string.
    DATA lv_action TYPE i.
    DATA lt_csv TYPE tt_csv.

    CLEAR: ev_file_name, ev_cancelled, ev_error.
    lt_csv = it_csv.

    cl_gui_frontend_services=>file_save_dialog(
      EXPORTING
        window_title      = 'Save S/4 change log'
        default_extension = 'csv'
        default_file_name = iv_default_name
        file_filter       = 'CSV files (*.csv)|*.csv|'
      CHANGING
        filename          = lv_filename
        path              = lv_path
        fullpath          = lv_fullpath
        user_action       = lv_action
      EXCEPTIONS
        cntl_error        = 1
        error_no_gui      = 2
        not_supported_by_gui = 3
        OTHERS            = 4 ).
    IF sy-subrc <> 0.
      ev_error = |Could not open the local file dialog (return code { sy-subrc }).|.
      RETURN.
    ENDIF.
    IF lv_action = cl_gui_frontend_services=>action_cancel.
      ev_cancelled = abap_true.
      RETURN.
    ENDIF.

    cl_gui_frontend_services=>gui_download(
      EXPORTING
        filename                = lv_fullpath
        filetype                = 'ASC'
        codepage                = '4110'
        write_bom               = abap_true
        confirm_overwrite       = abap_true
      CHANGING
        data_tab                = lt_csv
      EXCEPTIONS
        file_write_error        = 1
        no_batch                = 2
        gui_refuse_filetransfer = 3
        invalid_type            = 4
        no_authority            = 5
        unknown_error           = 6
        access_denied           = 15
        disk_full               = 17
        dp_timeout              = 18
        file_not_found          = 19
        dataprovider_exception  = 20
        control_flush_error     = 21
        not_supported_by_gui    = 22
        error_no_gui            = 23
        OTHERS                  = 24 ).
    IF sy-subrc <> 0.
      ev_error = |Could not write local file (return code { sy-subrc }).|.
      RETURN.
    ENDIF.

    ev_file_name = lv_fullpath.
  ENDMETHOD.

  METHOD write_server.
    DATA lv_file_name TYPE filename-fileextern.
    DATA lv_emergency TYPE c LENGTH 1.

    CLEAR: ev_file_name, ev_error.

    IF iv_logical_filename IS INITIAL.
      ev_error = 'Enter a logical filename configured in transaction FILE.'.
      RETURN.
    ENDIF.

    CALL FUNCTION 'FILE_GET_NAME'
      EXPORTING
        logical_filename   = iv_logical_filename
        parameter_1        = iv_parameter_1
        including_dir      = abap_true
        with_file_extension = abap_false
      IMPORTING
        emergency_flag     = lv_emergency
        file_name          = lv_file_name
      EXCEPTIONS
        file_not_found     = 1
        OTHERS             = 2.
    IF sy-subrc <> 0.
      ev_error = |Logical filename { iv_logical_filename } could not be resolved (return code { sy-subrc }).|.
      RETURN.
    ENDIF.
    IF lv_emergency IS NOT INITIAL.
      ev_error = |Logical filename { iv_logical_filename } used an emergency path; file not written.|.
      RETURN.
    ENDIF.

    TRY.
        OPEN DATASET lv_file_name
          FOR OUTPUT IN TEXT MODE ENCODING UTF-8.
        IF sy-subrc <> 0.
          ev_error = |Could not open application-server file { lv_file_name }.|.
          RETURN.
        ENDIF.

        LOOP AT it_csv ASSIGNING FIELD-SYMBOL(<lv_line>).
          TRANSFER <lv_line> TO lv_file_name.
          IF sy-subrc <> 0.
            CLOSE DATASET lv_file_name.
            ev_error = |Could not write application-server file { lv_file_name }.|.
            RETURN.
          ENDIF.
        ENDLOOP.
        CLOSE DATASET lv_file_name.
      CATCH cx_sy_file_error INTO DATA(lx_file).
        ev_error = lx_file->get_text( ).
        RETURN.
    ENDTRY.

    ev_file_name = lv_file_name.
  ENDMETHOD.
ENDCLASS.
