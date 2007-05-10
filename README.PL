potool jest programem wspomagaj±cym edycjê plików po
Copyright (C) 1999-2003 Zbigniew Chyla
Copyright (C) 2007 Marcin Owsiany

Licencja znajduje siê w pliku LICENSE

Pakiety potrzebne do kompilacji programu:
	gcc, bison, flex, glib 2.x w wersji -devel

Wywo³anie programu:

	potool FILENAME1 [FILENAME2] [-h] [-f f|nf|t|nt] [-s]
	       [-n ctxt|id|str|cmt|ucmt|pcmt|scmt|dcmt|tr|linf]...

Program pracuje w jednym z dwóch (na razie) trybów. W pierwszym wymaga
podania jednej nazwy pliku i dzia³a wówczas jak filtr. W drugim - powoduje
_zast±pienie_ t³umaczeñ w pliku FILENAME1 t³umaczeniami z pliku FILENAME2
(zatem pierwszy plik jest plikiem bazowym, za¶ drugi - naszym roboczym).

Opcja -f opisuje filtr, który okre¶la, jakie wpisy w pliku .po powinny byæ
uwzglêdniane (jest to filtr dzia³aj±cy przy odczycie pliku). W drugim
trybie pracy filtr uwzglêdniany jest tylko dla drugiego pliku (roboczego).

Istniej±ce filtry:
	t  - wpisy przet³umaczone,
	nt - wpisy nie przet³umaczone,
	f  - wpisy 'fuzzy',
	nf - wpisy bez oznaczenia fuzzy,
	o  - wpisy nieu¿ywane (oznaczone przedrostkiem "#~ ")
	no - wpisy u¿ywane

Filtry mo¿na na siebie nak³adaæ, np:

	potool gnumeric.po -fnt -nf

wy¶wietli wpisy z pliku 'gnumeric.po', które nie zosta³y przet³umaczone i
nie maj± oznaczenia 'fuzzy'.

Opcja -n dzia³a w obu trybach pracy tak samo i okre¶la, jakie informacje w
ka¿dym z wpisów _nie_ powinny byæ wy¶wietlane przy wypisywaniu ich przez
program. Dozwolona jest dowolna liczba opcji -n.

Dopuszczalne parametry:
	ctxt - nie wypisuj czê¶ci 'ctxt'
	id   - nie wypisuj czê¶ci 'id'
	str  - nie wypisuj czê¶ci 'str'
	tr   - nie wypisuj t³umaczeñ (lecz pust± czê¶æ 'str')
	ucmt - nie wypisuj komentarzy u¿ytkownika
	pcmt - nie wypisuj komentarzy okre¶laj±cych po³o¿enie w plikach
	scmt - nie wypisuj komentarzy specjalnych ('#, fuzzy, c-format, ...')
	dcmt - nie wy¶wietlaj komentarzy zarezerwowanych (g³ównie
               rozpoczynaj±cych siê kropk± - '#. ...'
	cmt  - nie wy¶wietlaj ¿adnych komentarzy (po³±czenie ucmt, pcmt,
               scmt, dcmt)
	linf - usuwaj informacjê o numerach linii w komentarzach
               okre¶laj±cych po³o¿enie w plikach (numery linii zamieniane s±
               na '1')

Dodatkowe opcje:
    -s powoduje wypisanie tylko liczby wpisów zamiast ich tre¶ci
    -c kopiuje we wszystkich wpisach czê¶æ 'id' do 'str'
       (byæ mo¿e zastêpuj±c t³umaczenie)

Przyk³ady u¿ycia:

	potool x.po -ftr
	- wy¶wietla liczbê przet³umaczonych wpisów

	potool x.po -nstr
	- oczyszcza plik z t³umaczeñ - a wiêc mo¿emy zaczynaæ od zera ;)

	(potool x.po -ftr && potool x.po -fntr)
	- wy¶wietla z pliku najpierw wpisy przet³umaczone, a nastêpnie nie
	  posiadaj±ce t³umaczenia (ze wzglêdu na pierwszy wpis nie zaleca
	  siê stosowania odwrotnej kolejno¶ci).
	  Plik taki zawiera wszystkie informacje z x.po, natomiast braki w
	  t³umaczeniach s± skupione w jednym miejscu

	potool x.po -fntr > tmp.po
	joe tmp.po
	potool x.po tmp.po
	- pozwala na proste dodawanie nowych t³umaczeñ, bez przegl±dania
	  starych.
