
--NUEVO PROCEDIMIENTO EN PKG_RECAUDACIONENVIO

--PROCEDURE P_GEN_ARCHIVOTXTBN IS
DECLARE
    v_archivo               UTL_FILE.FILE_TYPE;
    vDirectorio             VARCHAR2(500)       := 'RECAUDABANCOS';
    vPlantillaBancoNacion   VARCHAR2(300)       := '@VALOR1@@VALORFECHA@@VALOR2@-@VALOR3@@VALOR4@';

    vTotalImporteSoles      NUMBER(15,2);
    vTotalImporteDolares    NUMBER(15,2);
    vTotalRegistroSoles     NUMBER(10);
    vTotalRegistroDolares   NUMBER(10);

    --Datos BN--
    vCabeceraBN             VARCHAR2(400);
    vCodBancoBN             VARCHAR2(3)         := '018';
    vCodClienteBN           VARCHAR2(4)         := '0100';
    vTipoRegistroBN         VARCHAR2(2)         := '01';
    --Fin Datos BN--

    --Cursor Trama
    CURSOR cBN IS
    SELECT CAMPO FROM recaudabanconacionsoles WHERE TIPO = 2
    UNION ALL
    SELECT CAMPO FROM recaudabanconaciondolares WHERE TIPO = 2;

    BEGIN
        DBMS_OUTPUT.ENABLE;
        SELECT CAMPO INTO vTotalImporteSoles FROM recaudabanconacionsoles WHERE TIPO = 0;
        SELECT CAMPO INTO vTotalImporteDolares FROM recaudabanconaciondolares WHERE TIPO = 0;
        SELECT CAMPO INTO vTotalRegistroSoles FROM recaudabanconacionsoles WHERE TIPO = 1;
        SELECT CAMPO INTO vTotalRegistroDolares FROM recaudabanconaciondolares WHERE TIPO = 1;

        vCabeceraBN :=  vCodBancoBN ||                                                     --Codigo Banco
                        vCodClienteBN ||                                                   --Código Cliente
                        LPAD(vTotalRegistroSoles + vTotalRegistroDolares, 7, '0') ||       --Código de rubro
                        LPAD(NVL(vTotalImporteSoles, 0) * 100, 15, '0') ||                 --Suma Total Soles
                        LPAD(NVL(vTotalImporteDolares, 0) * 100, 15, '0') ||               --Suma Total Dolares
                        TO_CHAR(HOY, 'YYYYMMDD') ||                                        --Fecha de proceso
                        vTipoRegistroBN;                                                   --Tipo Registro
                        --LPAD(' ', 226, ' ');                                             --Espacios Reservados

        vPlantillaBancoNacion := REPLACE(vPlantillaBancoNacion, '@VALOR1@', 'R');                               --Valor Constante
        vPlantillaBancoNacion := REPLACE(vPlantillaBancoNacion, '@VALORFECHA@', TO_CHAR(HOY + 1,'YYYYMMDD'));   --Dia siguiente para dar tiempo a cargarlo en el sistema -BN
        vPlantillaBancoNacion := REPLACE(vPlantillaBancoNacion, '@VALOR2@', '01');                              --Valor Constante
        vPlantillaBancoNacion := REPLACE(vPlantillaBancoNacion, '@VALOR3@', '100');                             --Codigo Cliente
        vPlantillaBancoNacion := REPLACE(vPlantillaBancoNacion, '@VALOR4@', '.ING');      	                    --Extension

        --v_archivo := UTL_FILE.FOPEN(vDirectorio, vPlantillaBancoNacion,'W');
        --UTL_FILE.PUT_LINE(v_archivo, vCabeceraBN||CHR(13));
        DBMS_OUTPUT.PUT_LINE(vCabeceraBN);

        FOR x IN cBN LOOP 
            --UTL_FILE.PUT_LINE(v_archivo, x.campo||CHR(13));
            DBMS_OUTPUT.PUT_LINE(x.campo);
        END LOOP;

        --UTL_FILE.FCLOSE(v_archivo);
    EXCEPTION WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('ERROR GENERAR TXT BANCO NACION');
        --UTL_FILE.FCLOSE(v_archivo);
END P_GEN_ARCHIVOTXTBN;