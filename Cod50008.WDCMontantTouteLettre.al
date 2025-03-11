Codeunit 50008 "WDC Montant Toute Lettre"
{

    trigger OnRun()
    begin
    end;

    var
        million: Text[250];
        mille: Text[250];
        cent: Text[250];
        entiere: Integer;
        decimal: Integer;
        nbre: Integer;
        nbre1: Integer;
        chaine1: Text[30];
        VarDeviseEntiere: Text[30];
        VarDeviseDecimal: Text[30];


    procedure "Montant en texte"(var strprix: Text[1024]; prix: Decimal)
    begin
        entiere := ROUND(prix, 1, '<');
        decimal := ROUND((prix - entiere) * 1000, 1, '=');
        nbre := entiere;
        million := '';
        mille := '';
        cent := '';
        nbre1 := nbre DIV 1000000;
        IF nbre1 <> 0 THEN BEGIN
            Centaine(million, nbre1);
            million := million + ' million';
        END;
        nbre := nbre MOD 1000000;
        nbre1 := nbre DIV 1000;
        IF nbre1 <> 0 THEN BEGIN
            Centaine(mille, nbre1);
            IF mille <> 'un' THEN
                mille := mille + ' mille'
            ELSE
                mille := 'mille'
        END;

        nbre := nbre MOD 1000;

        IF nbre <> 0 THEN BEGIN
            Centaine(cent, nbre);
        END;

        IF million <> '' THEN
            strprix := million;
        IF ((mille <> '') AND (strprix <> '')) THEN
            strprix := strprix + ' ' + mille
        ELSE
            strprix := strprix + mille;
        IF ((cent <> '') AND (strprix <> '')) THEN
            strprix := strprix + ' ' + cent
        ELSE
            strprix := strprix + cent;

        IF entiere > 1 THEN
            strprix := strprix + ' dinars';
        IF entiere = 1 THEN
            strprix := strprix + ' dinar';

        cent := '';
        IF decimal <> 0 THEN BEGIN
            Centaine(cent, decimal);
            IF strprix <> '' THEN
                strprix := strprix + ' ' + cent
            ELSE
                strprix := strprix + cent;
            IF decimal = 1 THEN
                strprix := strprix + ' millime'
            ELSE
                strprix := strprix + ' millimes';
        END;

        strprix := UPPERCASE(strprix);
    end;


    procedure Centaine(var chaine: Text[250]; i: Integer)
    var
        k: Integer;
    begin
        k := i DIV 100;
        chaine := '';
        CASE k OF
            1:
                chaine := 'cent';
            2:
                chaine := 'deux cent';
            3:
                chaine := 'trois cent';
            4:
                chaine := 'quatre cent';
            5:
                chaine := 'cinq cent';
            6:
                chaine := 'six cent';
            7:
                chaine := 'sept cent';
            8:
                chaine := 'huit cent';
            9:
                chaine := 'neuf cent';
        END;
        k := i MOD 100;
        Dizaine(chaine, k);
    end;


    procedure Dizaine(var chaine: Text[250]; i: Integer)
    var
        k: Integer;
        l: Integer;
    begin
        IF i > 16 THEN BEGIN
            k := i DIV 10;
            chaine1 := '';
            CASE k OF
                1:
                    chaine1 := 'dix';
                2:
                    chaine1 := 'vingt';
                3:
                    chaine1 := 'trente';
                4:
                    chaine1 := 'quarante';
                5:
                    chaine1 := 'cinquante';
                6:
                    chaine1 := 'soixante';
                7:
                    chaine1 := 'soixante';
                8:
                    chaine1 := 'quatre vingt';
                9:
                    chaine1 := 'quatre vingt';
            END;
            IF ((chaine1 <> '') AND (chaine <> '')) THEN
                chaine1 := ' ' + chaine1;
            chaine := chaine + chaine1;
            l := k;
            IF ((k = 7) OR (k = 9)) THEN
                k := (i MOD 10) + 10
            ELSE
                k := (i MOD 10);
        END
        ELSE
            k := i;

        IF ((l <> 8) AND (l <> 0) AND ((k = 1) OR (k = 11))) THEN
            chaine := chaine + ' et';
        IF (((k = 0) OR (k > 16)) AND ((l = 7) OR (l = 9))) THEN BEGIN
            chaine := chaine + ' dix';
            IF k > 16 THEN
                k := k - 10;
        END;

        Unité(chaine, k);
    end;


    procedure "Unité"(var chaine: Text[250]; i: Integer)
    begin
        chaine1 := '';
        CASE i OF
            1:
                chaine1 := 'un';
            2:
                chaine1 := 'deux';
            3:
                chaine1 := 'trois';
            4:
                chaine1 := 'quatre';
            5:
                chaine1 := 'cinq';
            6:
                chaine1 := 'six';
            7:
                chaine1 := 'sept';
            8:
                chaine1 := 'huit';
            9:
                chaine1 := 'neuf';
            10:
                chaine1 := 'dix';
            11:
                chaine1 := 'onze';
            12:
                chaine1 := 'douze';
            13:
                chaine1 := 'treize';
            14:
                chaine1 := 'quatorze';
            15:
                chaine1 := 'quinze';
            16:
                chaine1 := 'seize';
        END;
        IF ((chaine1 <> '') AND (chaine <> '')) THEN
            chaine1 := ' ' + chaine1;
        chaine := chaine + chaine1;
    end;


    procedure "Montant en texte sans millimes"(var strprix: Text[250]; prix: Decimal)
    begin
        entiere := ROUND(prix, 1, '<');
        decimal := ROUND((prix - entiere) * 1000, 1, '<');
        nbre := entiere;
        //Chèque.FormatNumTexte(strprix,nbre);

        million := '';
        mille := '';
        cent := '';

        nbre1 := nbre DIV 1000000;
        IF nbre1 <> 0 THEN BEGIN
            Centaine(million, nbre1);
            million := million + ' million';
        END;

        nbre := nbre MOD 1000000;
        nbre1 := nbre DIV 1000;
        IF nbre1 <> 0 THEN BEGIN
            Centaine(mille, nbre1);
            IF mille <> 'un' THEN
                mille := mille + ' mille'
            ELSE
                mille := 'mille'
        END;

        nbre := nbre MOD 1000;

        IF nbre <> 0 THEN BEGIN
            Centaine(cent, nbre);
        END;

        IF million <> '' THEN
            strprix := million;
        IF ((mille <> '') AND (strprix <> '')) THEN
            strprix := strprix + ' ' + mille
        ELSE
            strprix := strprix + mille;
        IF ((cent <> '') AND (strprix <> '')) THEN
            strprix := strprix + ' ' + cent
        ELSE
            strprix := strprix + cent;

        IF entiere > 1 THEN
            strprix := strprix + ' dinars';
        IF entiere = 1 THEN
            strprix := strprix + ' dinar';

        IF decimal <> 0 THEN BEGIN
            IF strprix <> '' THEN
                strprix := strprix + ' ' + FORMAT(decimal)
            ELSE
                strprix := strprix + FORMAT(decimal);
            IF decimal = 1 THEN
                strprix := strprix + ' millime'
            ELSE
                strprix := strprix + ' millimes';
        END;

        strprix := UPPERCASE(strprix);
    end;


    procedure "Montant en texteDevise"(var strprix: Text[250]; prix: Decimal; Devise: Text[30])
    begin
        /*QuelleDevise(Devise,0);
        entiere := ROUND(prix,1,'<');
        decimal := ROUND((prix - entiere) * 100,1,'<');
        nbre := entiere;
        million := '';
        mille := '';
        cent := '';
        nbre1 := nbre DIV 1000000;
        IF nbre1 <> 0 THEN BEGIN
          Centaine(million,nbre1);
          million := million + ' million';
        END;
        nbre := nbre MOD 1000000;
        nbre1 := nbre DIV 1000;
        IF nbre1 <> 0 THEN BEGIN
          Centaine(mille,nbre1);
          IF mille <> 'un' THEN
            mille := mille + ' mille'
           ELSE
            mille := 'mille'
        END;
        
        nbre := nbre MOD 1000;
        
        IF nbre <> 0 THEN BEGIN
          Centaine(cent,nbre);
        END;
        
        IF million <> '' THEN
          strprix := million;
        IF ((mille <> '') AND (strprix <>'')) THEN
          strprix := strprix + ' ' + mille
         ELSE
          strprix := strprix + mille;
        IF ((cent <> '') AND (strprix <>'')) THEN
          strprix := strprix + ' ' + cent
         ELSE
          strprix := strprix + cent;
        
        IF entiere > 1 THEN
          strprix := strprix + ' ' + VarDeviseEntiere;
        IF entiere = 1 THEN
         strprix := strprix + ' ' + VarDeviseEntiere;
        
        cent := '';
        IF decimal <> 0 THEN BEGIN
          Centaine(cent,decimal);
          IF strprix <>'' THEN
            strprix := strprix + ' ' + cent
           ELSE
            strprix := strprix + cent;
          IF decimal = 1 THEN
            strprix := strprix + ' ' + VarDeviseDecimal
           ELSE
            strprix := strprix + ' ' + VarDeviseDecimal;
        
        
        
        END;
        
        strprix := UPPERCASE(strprix);
        */

        QuelleDevise(Devise, 0);
        entiere := ROUND(prix, 1, '<');
        decimal := ROUND((prix - entiere) * 100, 1, '<');
        nbre := entiere;
        million := '';
        mille := '';
        cent := '';
        nbre1 := nbre DIV 1000000;
        IF nbre1 <> 0 THEN BEGIN
            Centaine(million, nbre1);
            million := million + ' million';
        END;
        nbre := nbre MOD 1000000;
        nbre1 := nbre DIV 1000;
        IF nbre1 <> 0 THEN BEGIN
            Centaine(mille, nbre1);
            IF mille <> 'un' THEN
                mille := mille + ' mille'
            ELSE
                mille := 'mille'
        END;

        nbre := nbre MOD 1000;

        IF nbre <> 0 THEN BEGIN
            Centaine(cent, nbre);
        END;

        IF million <> '' THEN
            strprix := million;
        IF ((mille <> '') AND (strprix <> '')) THEN
            strprix := strprix + ' ' + mille
        ELSE
            strprix := strprix + mille;
        IF ((cent <> '') AND (strprix <> '')) THEN
            strprix := strprix + ' ' + cent
        ELSE
            strprix := strprix + cent;

        IF entiere > 1 THEN
            strprix := strprix + ' ' + VarDeviseEntiere;
        IF entiere = 1 THEN
            strprix := strprix + ' ' + VarDeviseEntiere;

        cent := '';
        IF decimal <> 0 THEN BEGIN
            Centaine(cent, decimal);
            IF strprix <> '' THEN
                strprix := strprix + ' ' + cent
            ELSE
                strprix := strprix + cent;
            IF decimal = 1 THEN
                strprix := strprix + ' ' + VarDeviseDecimal
            ELSE
                strprix := strprix + ' ' + VarDeviseDecimal;



        END;

        strprix := UPPERCASE(strprix);

    end;


    procedure QuelleDevise(var StrDevise: Text[30]; lng: Integer)
    begin

        IF StrDevise = 'USD' THEN
            CASE lng OF
                1033:
                    BEGIN
                        VarDeviseEntiere := 'US Dollars';
                        VarDeviseDecimal := 'Cents';
                    END;
                ELSE BEGIN
                    VarDeviseEntiere := 'Dollars US';
                    VarDeviseDecimal := 'Cents';
                END;
            END;

        IF StrDevise = 'EUR' THEN
            CASE lng OF
                1033:
                    BEGIN
                        VarDeviseEntiere := 'Euro';
                        VarDeviseDecimal := 'EuroCents';
                    END;
                ELSE BEGIN
                    VarDeviseEntiere := 'Euro';
                    VarDeviseDecimal := 'Centimes';
                END;
            END;

        IF StrDevise = '£' THEN
            CASE lng OF
                1033:
                    BEGIN
                        VarDeviseEntiere := 'Pounds';
                        VarDeviseDecimal := 'Cents';
                    END;
                ELSE BEGIN
                    VarDeviseEntiere := 'Livres Sterling';
                    VarDeviseDecimal := 'Cents';
                END;
            END;
    end;


    procedure MontantTexteLangue(var strprix: Text[250]; prix: Decimal; lng: Integer)
    begin
        entiere := ROUND(prix, 1, '<');
        decimal := ROUND((prix - entiere) * 1000, 1, '<');
        nbre := entiere;
        million := '';
        mille := '';
        cent := '';
        nbre1 := nbre DIV 1000000;
        IF nbre1 <> 0 THEN BEGIN
            CentaineLangue(million, nbre1, lng);
            CASE lng OF
                1033:
                    million := million + ' million';
                ELSE
                    million := million + ' million';
            END;
        END;

        nbre := nbre MOD 1000000;
        nbre1 := nbre DIV 1000;
        IF nbre1 <> 0 THEN BEGIN
            CentaineLangue(mille, nbre1, lng);
            IF mille <> 'un' THEN
                CASE lng OF
                    1033:
                        mille := mille + ' thousand';
                    ELSE
                        mille := mille + ' mille';
                END
            ELSE
                mille := 'mille'
        END;

        nbre := nbre MOD 1000;

        IF nbre <> 0 THEN BEGIN
            CentaineLangue(cent, nbre, lng);
        END;

        IF million <> '' THEN
            strprix := million;
        IF ((mille <> '') AND (strprix <> '')) THEN
            strprix := strprix + ' ' + mille
        ELSE
            strprix := strprix + mille;
        IF ((cent <> '') AND (strprix <> '')) THEN
            strprix := strprix + ' ' + cent
        ELSE
            strprix := strprix + cent;

        IF entiere > 1 THEN
            strprix := strprix + ' dinars';
        IF entiere = 1 THEN
            strprix := strprix + ' dinar';

        cent := '';
        IF decimal <> 0 THEN BEGIN
            CentaineLangue(cent, decimal, lng);
            IF strprix <> '' THEN
                strprix := strprix + ' ' + cent
            ELSE
                strprix := strprix + cent;
            IF decimal = 1 THEN
                strprix := strprix + ' millime'
            ELSE
                strprix := strprix + ' millimes';
        END;

        strprix := UPPERCASE(strprix);
    end;


    procedure MontantTexteDeviseLangue(var strprix: Text[250]; prix: Decimal; Devise: Text[30]; lng: Integer)
    begin
        QuelleDevise(Devise, lng);
        entiere := ROUND(prix, 1, '<');
        decimal := ROUND((prix - entiere) * 100, 1, '<');

        nbre := entiere;
        million := '';
        mille := '';
        cent := '';

        nbre1 := nbre DIV 1000000;
        IF nbre1 <> 0 THEN BEGIN
            CentaineLangue(million, nbre1, lng);
            CASE lng OF
                1033:
                    million := million + ' million';
                ELSE
                    million := million + ' million';
            END;
        END;

        nbre := nbre MOD 1000000;
        nbre1 := nbre DIV 1000;
        IF nbre1 <> 0 THEN BEGIN
            CentaineLangue(mille, nbre1, lng);
            IF mille <> 'un' THEN
                CASE lng OF
                    1033:
                        mille := mille + ' thousand';
                    ELSE
                        mille := mille + ' mille';
                END
            ELSE
                mille := 'mille'
        END;

        nbre := nbre MOD 1000;

        IF nbre <> 0 THEN BEGIN
            CentaineLangue(cent, nbre, lng);
        END;

        IF million <> '' THEN
            strprix := million;
        IF ((mille <> '') AND (strprix <> '')) THEN
            strprix := strprix + ' ' + mille
        ELSE
            strprix := strprix + mille;
        IF ((cent <> '') AND (strprix <> '')) THEN
            strprix := strprix + ' ' + cent
        ELSE
            strprix := strprix + cent;

        IF entiere > 1 THEN
            strprix := strprix + ' ' + VarDeviseEntiere;
        IF entiere = 1 THEN
            strprix := strprix + ' ' + VarDeviseEntiere;

        cent := '';
        IF decimal <> 0 THEN BEGIN
            CentaineLangue(cent, decimal, lng);
            IF strprix <> '' THEN
                strprix := strprix + ' ' + cent
            ELSE
                strprix := strprix + cent;
            IF decimal = 1 THEN
                strprix := strprix + ' ' + VarDeviseDecimal
            ELSE
                strprix := strprix + ' ' + VarDeviseDecimal;



        END;

        strprix := UPPERCASE(strprix);
    end;


    procedure CentaineLangue(var chaine: Text[250]; i: Integer; lng: Integer)
    var
        k: Integer;
    begin
        k := i DIV 100;
        chaine := '';
        CASE lng OF
            1033:
                BEGIN
                    CASE k OF
                        1:
                            chaine := 'one hundred';
                        2:
                            chaine := 'two hundred';
                        3:
                            chaine := 'three hundred';
                        4:
                            chaine := 'four hundred';
                        5:
                            chaine := 'five hundred';
                        6:
                            chaine := 'six hundred';
                        7:
                            chaine := 'seven hundred';
                        8:
                            chaine := 'height hundred';
                        9:
                            chaine := 'nine hundred';
                    END;
                END;
            ELSE BEGIN
                CASE k OF
                    1:
                        chaine := 'cent';
                    2:
                        chaine := 'deux cent';
                    3:
                        chaine := 'trois cent';
                    4:
                        chaine := 'quatre cent';
                    5:
                        chaine := 'cinq cent';
                    6:
                        chaine := 'six cent';
                    7:
                        chaine := 'sept cent';
                    8:
                        chaine := 'huit cent';
                    9:
                        chaine := 'neuf cent';
                END;
            END;
        END;
        k := i MOD 100;
        DizaineLangue(chaine, k, lng);
    end;


    procedure DizaineLangue(var chaine: Text[250]; i: Integer; lng: Integer)
    var
        k: Integer;
        l: Integer;
    begin
        CASE lng OF
            1033:
                BEGIN
                    IF i > 19 THEN BEGIN
                        k := i DIV 10;
                        chaine1 := '';
                        CASE k OF
                            1:
                                chaine1 := 'ten';
                            2:
                                chaine1 := 'twenty';
                            3:
                                chaine1 := 'thirty';
                            4:
                                chaine1 := 'fourty';
                            5:
                                chaine1 := 'fivety';
                            6:
                                chaine1 := 'sixty';
                            7:
                                chaine1 := 'seventy';
                            8:
                                chaine1 := 'heighty';
                            9:
                                chaine1 := 'ninety';
                        END;
                        IF ((chaine1 <> '') AND (chaine <> '')) THEN
                            chaine1 := ' ' + chaine1;
                        chaine := chaine + chaine1;
                        l := k;
                        k := (i MOD 10);
                    END
                    ELSE
                        k := i;

                    IF ((l <> 8) AND (l <> 0) AND ((k = 11) OR (k = 11))) THEN
                        chaine := chaine + ' and';
                    IF (((k = 0) OR (k > 19)) AND ((l = 7) OR (l = 9))) THEN BEGIN
                        chaine := chaine + ' dix';
                        IF k > 19 THEN
                            k := k - 10;
                    END;
                END;
            ELSE BEGIN
                IF i > 16 THEN BEGIN
                    k := i DIV 10;
                    chaine1 := '';
                    CASE k OF
                        1:
                            chaine1 := 'dix';
                        2:
                            chaine1 := 'vingt';
                        3:
                            chaine1 := 'trente';
                        4:
                            chaine1 := 'quarante';
                        5:
                            chaine1 := 'cinquante';
                        6:
                            chaine1 := 'soixante';
                        7:
                            chaine1 := 'soixante';
                        8:
                            chaine1 := 'quatre vingt';
                        9:
                            chaine1 := 'quatre vingt';
                    END;
                    IF ((chaine1 <> '') AND (chaine <> '')) THEN
                        chaine1 := ' ' + chaine1;
                    chaine := chaine + chaine1;
                    l := k;
                    IF ((k = 7) OR (k = 9)) THEN
                        k := (i MOD 10) + 10
                    ELSE
                        k := (i MOD 10);
                END
                ELSE
                    k := i;

                IF ((l <> 8) AND (l <> 0) AND ((k = 1) OR (k = 11))) THEN
                    chaine := chaine + ' et';
                IF (((k = 0) OR (k > 16)) AND ((l = 7) OR (l = 9))) THEN BEGIN
                    chaine := chaine + ' dix';
                    IF k > 16 THEN
                        k := k - 10;
                END;
            END;
        END;
        UnitéLangue(chaine, k, lng);
    end;


    procedure "UnitéLangue"(var chaine: Text[250]; i: Integer; lng: Integer)
    begin
        chaine1 := '';
        CASE lng OF
            1033:
                CASE i OF
                    1:
                        chaine1 := 'one';
                    2:
                        chaine1 := 'two';
                    3:
                        chaine1 := 'three';
                    4:
                        chaine1 := 'four';
                    5:
                        chaine1 := 'five';
                    6:
                        chaine1 := 'six';
                    7:
                        chaine1 := 'seven';
                    8:
                        chaine1 := 'height';
                    9:
                        chaine1 := 'nine';
                    10:
                        chaine1 := 'ten';
                    11:
                        chaine1 := 'eleven';
                    12:
                        chaine1 := 'twelve';
                    13:
                        chaine1 := 'thirteen';
                    14:
                        chaine1 := 'fourteen';
                    15:
                        chaine1 := 'fifteen';
                    16:
                        chaine1 := 'sixteen';
                    17:
                        chaine1 := 'seventeen';
                    18:
                        chaine1 := 'heighteen';
                    19:
                        chaine1 := 'ninteen';
                END;
            ELSE
                CASE i OF
                    1:
                        chaine1 := 'un';
                    2:
                        chaine1 := 'deux';
                    3:
                        chaine1 := 'trois';
                    4:
                        chaine1 := 'quatre';
                    5:
                        chaine1 := 'cinq';
                    6:
                        chaine1 := 'six';
                    7:
                        chaine1 := 'sept';
                    8:
                        chaine1 := 'huit';
                    9:
                        chaine1 := 'neuf';
                    10:
                        chaine1 := 'dix';
                    11:
                        chaine1 := 'onze';
                    12:
                        chaine1 := 'douze';
                    13:
                        chaine1 := 'treize';
                    14:
                        chaine1 := 'quatorze';
                    15:
                        chaine1 := 'quinze';
                    16:
                        chaine1 := 'seize';
                END;
        END;
        IF ((chaine1 <> '') AND (chaine <> '')) THEN
            chaine1 := ' ' + chaine1;
        chaine := chaine + chaine1;
    end;


    procedure "Montant DEVISE"(var strprix: Text[250]; prix: Decimal; Devise: Code[20])
    var
        Devisetext: Text[30];
    begin
        entiere := ROUND(prix, 1, '<');
        //decimal := ROUND((prix - entiere) * 1000,1,'<');
        decimal := ROUND((prix - entiere) * 100, 1, '<');
        nbre := entiere;
        //Chèque.FormatNumTexte(strprix,nbre);

        million := '';
        mille := '';
        cent := '';

        nbre1 := nbre DIV 1000000;
        IF nbre1 <> 0 THEN BEGIN
            Centaine(million, nbre1);
            million := million + ' million';
        END;

        nbre := nbre MOD 1000000;
        nbre1 := nbre DIV 1000;
        IF nbre1 <> 0 THEN BEGIN
            Centaine(mille, nbre1);
            IF mille <> 'un' THEN
                mille := mille + ' mille'
            ELSE
                mille := 'mille'
        END;

        nbre := nbre MOD 1000;

        IF nbre <> 0 THEN BEGIN
            Centaine(cent, nbre);
        END;

        IF million <> '' THEN
            strprix := million;
        IF ((mille <> '') AND (strprix <> '')) THEN
            strprix := strprix + ' ' + mille
        ELSE
            strprix := strprix + mille;
        IF ((cent <> '') AND (strprix <> '')) THEN
            strprix := strprix + ' ' + cent
        ELSE
            strprix := strprix + cent;
        IF Devise = 'EUR' THEN
            Devisetext := 'EURO'
        ELSE
            Devisetext := FORMAT(Devise);
        QuelleDevise(Devisetext, 0);
        IF entiere > 1 THEN
            strprix := strprix + ' ' + Devisetext;
        IF entiere = 1 THEN
            strprix := strprix + ' ' + Devisetext + 'S';

        IF decimal <> 0 THEN BEGIN
            IF strprix <> '' THEN
                strprix := strprix + ' ' + FORMAT(decimal, 2)
            ELSE
                strprix := strprix + FORMAT(decimal, 2);
            IF decimal = 1 THEN
                strprix := strprix + ' Centime'
            ELSE
                strprix := strprix + ' Centimes';
        END;

        strprix := UPPERCASE(strprix);
    end;
}

