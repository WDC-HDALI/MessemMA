codeunit 50009 "WDC Import PAIE Excel"
{
    procedure ReadExcelSheet()
    var
        FileName: Text[100];
        SheetName: Text[100];
        FileMgt: Codeunit "File Management";
        IStream: InStream;
        FromFile: Text[100];
        UploadExcelMsg: Label 'Veuillez importer le fichier à partir du chemin approprié';
        NoFileFoundMsg: Label 'Le fichier n''a pas été trouvé';
        TempExcelBuffer: Record "Excel Buffer" temporary;
    begin
        UploadIntoStream(UploadExcelMsg, '', '', FromFile, IStream);
        if FromFile <> '' then begin
            FileName := FileMgt.GetFileName(FromFile);

            SheetName := TempExcelBuffer.SelectSheetsNameStream(IStream);

            if SheetName = '' then
                Error('Erreur : Impossible de détecter la feuille Excel.');
        end else
            Error(NoFileFoundMsg);

        TempExcelBuffer.Reset();
        TempExcelBuffer.DeleteAll();

        //Ouvre le fichier Excel en mode Cloud
        TempExcelBuffer.OpenBookStream(IStream, SheetName);
        //Lire les données
        TempExcelBuffer.ReadSheet();
        // Vérifie si des données ont été lues
        if TempExcelBuffer.IsEmpty() then
            Error('Erreur : Les données ne sont pas correctement lues. Vérifiez que la première ligne contient des en-têtes valides.');

        ImportExcelData(TempExcelBuffer);
    end;

    local procedure ImportExcelData(var TempExcelBuffer: Record "Excel Buffer" temporary)
    var
        GenJournal: Record "Gen. Journal Line";
        RowNo: Integer;
        MaxRowNo: Integer;
        increment: Integer;
        Solde: Decimal;
        DimensionValue: Record "Dimension Value";
        ExcelImportSuccess: Label 'Opération terminée avec succès!';
    begin
        RowNo := 0;
        MaxRowNo := 0;
        increment := 1000;
        //Suppression des données de la feuille paie
        Clear(GenJournal);
        GenJournal.SetRange("Journal Template Name", 'PAIE');
        GenJournal.SetRange(GenJournal."Journal Batch Name", 'PAIE');
        if GenJournal.FindSet() then
            GenJournal.DeleteAll();
        // Récupération du dernier numéro de ligne du fichier Excel
        if TempExcelBuffer.FindLast() then
            MaxRowNo := TempExcelBuffer."Row No.";

        for RowNo := 2 to MaxRowNo do begin
            GenJournal.Init();
            Clear(Solde);
            increment += 1;
            Evaluate(GenJournal."Journal Template Name", 'PAIE');
            Evaluate(GenJournal."Journal Batch Name", 'PAIE');
            GenJournal."Line No." := Increment;
            Evaluate(GenJournal."Document No.", GetValueAtCell(TempExcelBuffer, RowNo, 1));
            Evaluate(GenJournal."Posting Date", GetValueAtCell(TempExcelBuffer, RowNo, 2));
            //Axe analytique
            Clear(DimensionValue);
            DimensionValue.setrange("Dimension Code", 'DEPARTMENT');
            IF DimensionValue.FindSet() THEN
                Repeat
                    if uppercase(Format(DimensionValue.Name)) = UpperCase(GetValueAtCell(TempExcelBuffer, RowNo, 3)) then
                        GenJournal.Validate("Shortcut Dimension 2 Code", DimensionValue.Code);
                Until DimensionValue.next = 0;
            GenJournal."Account Type" := GenJournal."Account Type"::"G/L Account";
            Evaluate(GenJournal."Account No.", GetValueAtCell(TempExcelBuffer, RowNo, 4));
            Evaluate(GenJournal."Description", GetValueAtCell(TempExcelBuffer, RowNo, 5));
            Solde := ConvertToDecimal(GetValueAtCell(TempExcelBuffer, RowNo, 6)) - ConvertToDecimal(GetValueAtCell(TempExcelBuffer, RowNo, 7));
            GenJournal.Validate(Amount, Solde);
            GenJournal."Gen. Bus. Posting Group" := '';
            GenJournal."Gen. Prod. Posting Group" := '';
            GenJournal."VAT Bus. Posting Group" := '';
            if solde <> 0 then
                GenJournal.Insert();
        end;
        Message(ExcelImportSuccess);
    end;

    local procedure GetValueAtCell(var TempExcelBuffer: Record "Excel Buffer" temporary; RowNo: Integer; ColNo: Integer): Text
    begin
        TempExcelBuffer.Reset();
        if TempExcelBuffer.Get(RowNo, ColNo) then
            exit(TempExcelBuffer."Cell Value as Text")
        else
            exit('');
    end;

    local procedure ConvertToDecimal(ValueAsText: Text): Decimal
    var
        ConvertedValue: Decimal;
    begin
        if not Evaluate(ConvertedValue, ValueAsText) then
            ConvertedValue := 0;
        exit(ConvertedValue);

    end;
}
