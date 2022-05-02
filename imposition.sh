#!/bin/zsh

INPUTFILE="damouretdeguerre.pdf"
NUMBEROFFOLIOPERBOOKLET=10 # The number of paper used for each booklet
TOTALNUMBEROFPAGES=$(exiftool $INPUTFILE | grep "Page Count" | sed "s/Page Count  *: //")
(( INTERIORNUMBEROFPAGES=$TOTALNUMBEROFPAGES-4 )) # The remaining page number after cover extraction
(( FOLIA=$INTERIORNUMBEROFPAGES/4 ))
(( NUMBEROFBOOKLET=$FOLIA/$NUMBEROFFOLIOPERBOOKLET ))
(( NUMBEROFPAGESPERBOOKLET=$NUMBEROFFOLIOPERBOOKLET*4 ))
(( HAFPAGENUMBEROFPAGESPERBOOKLET=$NUMBEROFPAGESPERBOOKLET/2 )) # Usefull to leave the booklet loop 



print "Nombre de pages intérieures : $INTERIORNUMBEROFPAGES"
print "Nombre de folia             : $FOLIA"
print "Nombre de cahiers           : $NUMBEROFBOOKLET"
print "Nombre de page par cahier   : $NUMBEROFPAGESPERBOOKLET"

# Fonctions agissants sur les pdfs
function normalizeNumber() {
	# Ajoute des zéros non significatifs de telle sorte à ce que tous les nombres soient constitués de trois chiffres
	normalized=$(printf '%03d\n' $1)
	echo $normalized
}

function makebookletpage() {
	# Prépare le recto de chaque folio
	bookletPageNormalized=$(normalizeNumber $3)
	pageleft=$(normalizeNumber $2)
	pageright=$(normalizeNumber $1)
	echo "Traitmeent des pages $pageleft et $pageright ; Page $bookletPageNormalized du livret"
	pdfjam /tmp/page_{$pageleft,$pageright}.pdf  --nup 2x1 --landscape --outfile /tmp/booklet-$bookletPageNormalized.pdf
}

function makereversedbookletpage() {
	# Prépare le verso de chaque folio
	bookletPageNormalized=$(normalizeNumber $3)
	pageleft=$(normalizeNumber $1)
	pageright=$(normalizeNumber $2)
	echo "Traitmeent des pages $pageleft et $pageright ; Page $normalizeNumber du livret"
	pdfjam /tmp/page_{$pageleft,$pageright}.pdf  --nup 2x1 --landscape --outfile /tmp/booklet-$bookletPageNormalized.pdf
}


# Fonction de distribution des pages
function getLastPageOfCurrentBooklet()
{
	# Trouve le numéro de la dernière page d’un cahier
	(( LASTPAGE=$1+$NUMBEROFPAGESPERBOOKLET ))
	if [ $LASTPAGE -le $INTERIORNUMBEROFPAGES ] ; then
		echo $LASTPAGE
	else
		echo $INTERIORNUMBEROFPAGES
	fi
}

function getMiddlePageOfBooklet()
{
	(( MIDDLEPAGE=($1+$2)/2 ))
	echo $MIDDLEPAGE
}

function getRelativeMiddlePageOfBooklet()
{
	# Trouve le numéro relatif de la page médiane d’un cahier.
	# Est surtout utile pour l’itération du dernier cahier pour lequel le nombre de flia est différent des autres cahiers.
	(( MIDDLEPAGE=($2-$1)/2 ))
	echo $MIDDLEPAGE
}


# Procéssus

echo "########################################################################"
echo " Préparation de l’imposition "
echo "########################################################################"
echo "Extraction de la couverture"
pdftk $INPUTFILE cat 3-r3 output /tmp/tmp-onlybooklet.pdf
echo "Éclatement des pages"
pdftk /tmp/tmp-onlybooklet.pdf burst output /tmp/page_%03d.pdf

page=0
FIRSTBOOKLETPAGE=0
BOOKLETNUMBER=1
BOOKLETPAGENUMBER=1
while [ $page -lt $INTERIORNUMBEROFPAGES ] ; do
	# Booklet loop initialisation
	LASTPAGEOFCURRENTBOOKLET=$(getLastPageOfCurrentBooklet $page)
	MIDDLEPAGE=$(getRelativeMiddlePageOfBooklet $page $LASTPAGEOFCURRENTBOOKLET)
	echo "------------------------------------------------------------------------"
	echo "Cahier $BOOKLETNUMBER"
	echo "Dernière page du feuillet : $LASTPAGEOFCURRENTBOOKLET"
	echo "Page centrale : $MIDDLEPAGE"

	# Entering Folio
	BOOKLETCURSOR=0
	while [ $BOOKLETCURSOR -lt $MIDDLEPAGE ] ; do
		# Initializing variables for each iteration
		(( first=$page+1+$BOOKLETCURSOR ))
		(( second=$page+2+$BOOKLETCURSOR ))
		(( last=$LASTPAGEOFCURRENTBOOKLET-$BOOKLETCURSOR ))
		(( penultimate=$last-1 ))

		#   Folio repartition:
		#
		#   Recto                   Verso
		#   +--------+--------+     +--------+--------+
		#   |        |        |     |        |        |
		#   |        |        |     |        |        |
		#   | last   | first  |     | second | penul- |
		#   |        |        |     |        | timate |
		#   |        |        |     |        |        |
		#   |        |        |     |        |        |
		#   +--------+--------+     +--------+--------+
		#        │        ╰─────────────╯        │
		#        │                               │
		#        ╰───────────────────────────────╯

		# Process on pdf files.
		echo "$BOOKLETCURSOR	$first $last	$BOOKLETPAGENUMBER"
		makebookletpage $first $last	$BOOKLETPAGENUMBER
		(( BOOKLETPAGENUMBER=$BOOKLETPAGENUMBER+1 ))
		echo "	$second $penultimate	$BOOKLETPAGENUMBER"
		makereversedbookletpage $second $penultimate	$BOOKLETPAGENUMBER

		# End of folio iteration
		(( BOOKLETPAGENUMBER=$BOOKLETPAGENUMBER+1 ))
		(( BOOKLETCURSOR=$BOOKLETCURSOR+2 ))
	done

	# End of booklet iteration
	(( page=$LASTPAGEOFCURRENTBOOKLET ))
	(( BOOKLETNUMBER=$BOOKLETNUMBER+1 ))
done

(( BOOKLETPAGENUMBER=$BOOKLETPAGENUMBER-1 )) # Annulate the last supernumerary incrementation to feet the real number of total iteration
echo "Concaténation finale des pages du livret"

# Concatenate all the folia in a final linear PDF
pdftk /tmp/booklet-{001..$BOOKLETPAGENUMBER}.pdf cat output damour-et-de-guerre-IMPOSE.pdf
