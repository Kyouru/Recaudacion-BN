
--AGREGAR A PKG_RECAUDACIONENVIO

PROCEDURE P_GEN_ARCHIVOTXT_BN IS
  v_archivo      UTL_FILE.FILE_TYPE;
  vDirectorio    VARCHAR2(500):='RECAUDABANCOS';
  vNombrearchivo VARCHAR2(500):=' ' ;
  vPlantillaBancoNacion VARCHAR2(300):='@VALOR1@@VALORFECHA@@VALOR2@@VALOR3@@VALOR4@';

  vTotalImporteSoles    NUMBER(15,2);
  vTotalImporteDolares    NUMBER(15,2);
  vTotalRegistroSoles    NUMBER(10);
  vTotalRegistroDolares    NUMBER(10);

  --Datos BN--
  --Tipos de Registo
  vCabeceraBN        VARCHAR2(400);
  --

  --Fin Datos BN--

  CURSOR cBN IS
  SELECT CAMPO FROM RECAUDABANCONACIONSOLES WHERE TIPO = 2
  UNION ALL
  SELECT CAMPO FROM RECAUDABANCONACIONDOLARES WHERE TIPO = 2;

BEGIN
  SELECT CAMPO INTO vTotalImporteSoles FROM RECAUDABANCONACIONSOLES WHERE TIPO = 0;
  SELECT CAMPO INTO vTotalImporteDolares FROM RECAUDABANCONACIONDOLARES WHERE TIPO = 0;
  SELECT CAMPO INTO vTotalRegistroSoles FROM RECAUDABANCONACIONSOLES WHERE TIPO = 1;
  SELECT CAMPO INTO vTotalRegistroDolares FROM RECAUDABANCONACIONDOLARES WHERE TIPO = 1;
  

    vCabeceraBN :=  vCodBancoBN ||                                --Codigo Banco
                    vCodClienteBN ||                              --Código Cliente
                    LPAD(vTotalRegistroSoles + vTotalRegistroDolares, 7, '0') ||              --Código de rubro
                    LPAD((CASE WHEN (PIMONEDA) = 1 THEN NVL(vTotalImporteSoles, 0) * 100 ELSE 0 END), 15, '0') ||
                                                                --Suma Total Soles
                    LPAD((CASE WHEN (PIMONEDA) = 2 THEN NVL(vTotalImporteDolares, 0) * 100 ELSE 0 END), 15, '0') ||
                                                                --Suma Total Dolares
                    TO_CHAR(HOY, 'YYYYMMDD') ||                 --Fecha de proceso
                    vTipoRegistroBN ||                              --Tipo Registro
                    LPAD(' ', 226, ' ');                        --Espacios

  vNombrearchivo :=REPLACE(vPlantillaBancoNacion, '@VALOR1@', 'R');   --Valor Constante
  vNombrearchivo := REPLACE(vPlantillaBancoNacion, '@VALORFECHA@', TO_CHAR(HOY,'YYYYMMDD'));
  vNombrearchivo :=REPLACE(vNombrearchivo, '@VALOR2@', '01');   --Valor Constante
  vNombrearchivo :=REPLACE(vNombrearchivo, '@VALOR3@', '100');   ---Codigo Cliente
  vNombrearchivo :=REPLACE(vNombrearchivo, '@VALOR4@', '.ING');    ---Extencion
  
  v_archivo := UTL_FILE.FOPEN(vDirectorio, vNombrearchivo,'W');
  --DELETE FROM RECAUDABANCONACION;
  --COMMIT;

  UTL_FILE.PUT_LINE(v_archivo, vCabeceraBN||CHR(13));
  --INSERT INTO RECAUDABANCONACION (CAMPO) VALUES (vCabeceraBN);

  FOR x IN cBN LOOP 
    UTL_FILE.PUT_LINE(v_archivo, x.campo||CHR(13));
    --INSERT INTO RECAUDABANCONACION (CAMPO) VALUES (x.campo);
  END LOOP;
  --COMMIT;
  UTL_FILE.FCLOSE(v_archivo);
EXCEPTION WHEN OTHERS THEN
  DBMS_OUTPUT.PUT_LINE('ERROR GENERAR TXT BANCO NACION');
  UTL_FILE.FCLOSE(v_archivo);
END P_GEN_ARCHIVOTXT_BN;