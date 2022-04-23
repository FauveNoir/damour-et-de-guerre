# Makefile

########################################################################
# Variables primordiales                                               #
########################################################################
NAME          = damouretdeguerre# # Le nom du projet, cette variable sera       #
                         # placée à la racine du nom de fichier de     #
                         # sortie                                      #
########################################################################
DOUBLEEDITION = no#      # Doit être placé à `true` pour les cas où    #
                         # l’on désire maintenir deux éditions         #
                         # concurentes.                                #
########################################################################

#############################################################################

########################################################################
# Traitement préliminaire des options requises à la compilation        #
########################################################################

ifeq ($(COMMON),false) # Si l’édition savante est explicitement requise à la compilation OU que l’édition commune n’est pas spécifiée.
  SCHOLARLY=true
endif
ifndef COMMON
  ifneq ($(SCHOLARLY),false)
    SCHOLARLY=true
  endif
endif

ifeq ($(DOUBLEEDITION),true) # Le bloc suivant n’est actif que pour les projets dévelopant une biédition.
  TEXARGS      += \\def\\isscholarly{1} # Par défaut, l’édition savante est traitée.

  ifeq ($(SCHOLARLY),true) # Si l’édition savante est explicitement requise à la compilation OU que l’édition commune n’est pas spécifiée.
    TEXARGS += \\def\\isscholarly{1} # Variable LaTeX qui sera incluse dans les sources LaTeX pour signifier que la version savante est requise.
    TEXARGS += \\let\\iscommon\\undefined # Désactive dans le code LaTeX toute mention à la version commune.
    SUFFIX  :=${SUFFIX}-Ed.-sav# Déffinit le suffixe du fichier de sortie à `Ed.-sav` pour l’édition savante.
    MAINFILE = main-scholarly.tex # Définit le fichier principal de projet LaTeX contenant le préambule et les déffintions minimale pour l’édition savante.
  else
    TEXARGS += \\def\\iscommon{1}# Indique a LaTeX que l’édition comune est considére.
    TEXARGS += \\let\\isscholarly\\undefined# Corolaire : indique à LaTeX de ne pas tenir compte des spécificités de l’édition commune.
    SUFFIX  :=${SUFFIX}-Ed.-com# Suffixe du nom de fichier de sortie pour l’édition commune.
    MAINFILE = main-common.tex# Définit le fichier principal de projet LaTeX à appeler lors de l’éxecution de la ligne de commande.
  endif

else
  MAINFILE = main.tex# Dans le cas où le projet n’éxige pas de double-édition, un fichier principal unique est déffinit pour tous les cas.
endif

########################################################################

ifeq ($(OFFENSIVE),false)
  NOOFFENSIVE=true
endif
ifndef OFFENSIVE
  ifneq ($(NOOFFENSIVE),false)
    NOOFFENSIVE=true
  endif
endif

ifeq ($(NOOFFENSIVE),true) # Si l’option de bienséance est requise, une variable injectée dans LaTeX l’indique.
  TEXARGS += \\let\\isoffensive\\undefined
endif

ifeq ($(OFFENSIVE),true) # Si l’option d’agressivité est *explicitement* requise à la compilation, une variable est injectée dans le code LaTeX et un suffixe est ajouté au fichier de sortie.
  TEXARGS += \\def\\isoffensive{1}# Variable pour LaTeX.
  SUFFIX  :=${SUFFIX}-agressif# Suffixe du fichier de sortie.
endif

########################################################################

ifeq ($(PRINTABLE), true) # Si l’option d’impression est *explicitement* requise, alors une variable est injectée dans le code LaTeX et un suffix est ajouté au fichier de sortie.
  TEXARGS += \\def\\isprintable{1}
  SUFFIX  :=${SUFFIX}-imprim
endif

########################################################################

ifeq ($(MONOCHROME),false)
  COLOR=true
endif
ifndef MONOCHROME
  ifneq ($(COLOR),false)
    COLOR=true
  endif
endif

ifeq ($(COLOR), true) # Si l’option colore est requise, une variable l’indiquant est injectée au code LaTeX.
  TEXARGS += \\let\\ismonochrome\\undefined
endif

ifeq ($(MONOCHROME), true) # Si, au contraire, l’option monochrome est requise, une variable est injectée au code LaTeX et un suffix est ajouté au fichier de sortie.
  TEXARGS += \\def\\ismonochrome{1}
  SUFFIX  :=${SUFFIX}-NB
endif

########################################################################
# Déffinition des principales variables                                #
########################################################################

TEX             = xelatex # Compilateur.
PDF             = mimeopen # Logiciel de lecture des fichiers de sortie. La commande `mimeopen` choisi normalement le lecteur par défaut déffinit pour un type de format de fichier donné.
PROCNAME        = ${NAME}${SUFFIX}# Variable formant le nom final du fichier de sortie avec les suffixes nécéssaires, selon les options de compilation demandées.

ifdef TEXARGS # Si des variables suplémentaires sont à injecter, alors nous les injectons.
  COMPIL        = ${TEX} -jobname=${PROCNAME}  "${TEXARGS} \input{${MAINFILE}}"
else # Sinon, nous ne nous les injectons pas et compilons simplement par l’appel au fichier principal.
  COMPIL        = ${TEX} -jobname=${PROCNAME}  "\input{${MAINFILE}}"
endif

FULLCOMPIL      = ${COMPIL} ; ${COMPIL} # Double compilation.
PRODUCED        = ^${NAME}((-Ed.-(sav|com)|)(-agressif|)(-imprim|)(-NB|)\.pdf|\.tar\.gz)$$# Variable contenant les noms des différentes possibilités de noms de fichiers de sorties.
BIB             = bibtex # Déffinition du gestionnaire de bibliographie.
MAKEGLOS        = makeglossaries # déffinition du gestionnaire de dictionnaire.
MAKEGITHISTORIC = git log --format="%ad & %s \\\\ " --date=short # Commande de création d’un tableau latex de l’historique de révision d’après l’arbre de Git.
SVGTXTSOURCES   = file\.svg # Liste des images SVG contenant du texte à inclure et dont la conversion en pdf doit placer le texte dans un fichier différent afin qu’il soit géré par LaTeX. [Les fichiers placés ici sont protégés de la supression]
MAKETEXTIMAGE   = for f in ${SVGSOURCES} ; do inkscape --export-latex --export-pdf=$$f.pdf $$f; done # Conversion en pdf tout en permetant à LaTeX de gérer les textes.
SVGSOURCES      = file\.svg # Liste des images SVG ne contenant pas de texte à convertir en SVG. [Les fichiers placés ici sont protégés de la supression]
MAKEIMAGE       = for f in ${SVGSOURCES} ; do inkscape --export-png=$$f.pdf $$f; done # Conversion des images SVG en PNG simple.

PRINT           = lpr # Commande d’impression.

# Liste des fichiers à archiver.
PROTECTED       = ^\.git$$

########################################################################
# Traitement des principaux arguments                                  #
########################################################################

all:
	make compile

compile:
	${COMPIL} ;
	#$(MAKEGLOS) ${PROCNAME}.glo ; # Traitmeent du glossaire [À décomenter si besoin de glossaire].
ifeq ($(SCHOLARLY),true) # Le bloc suivant n’est actif que pour les projets dévelopant une biédition.
	$(BIB)      ${PROCNAME} ; # Traitement de la bibliographie [À décomenter si besoin de bibliographie].
	${FULLCOMPIL}
endif

simplecomplie:
	${COMPIL}

historic:
	echo "% vim: syntax=tex" > githistoric.tex ; # Placement d’une indication pour vim afin de gérer correctement la coloration syntaxique.
	${MAKEGITHISTORIC} >> githistoric.tex # Mise à jour de l’historique de révision par écrasement de la précédente version.

graphics:
	${MAKEIMAGE}     ; # Conversion des images simples
	${MAKETEXTIMAGE} # Conversion des images à texte.

view: ${PROCNAME}.pdf
	$(PDF) ${PROCNAME}.pdf & # Visionage du fichier de sortie à l’aide du lecteur déffinit par défaut par le système.

print: ${PROCNAME}.pdf
ifdef PRINTABLE
	${PRINT} ${PROCNAME}.pdf # Si l’impression d’un document est demandée avec l’option d’impression activée, alors imprimer immédiatement.
else # Sinon, avertir de la perte de donnée occasionée par les formats non-adaptés à l’impression.
	echo "AVIS : Vous tentez d’imprimer une version non adaptée à cet effet."; echo "Par exemple, les liens sont cliquables et n’aparraissent pas au tirrage, ce qui constitue une perte d’information." ; ANSWERISCORRECT="no" ; read -p "Souhaitez vous continuer, tout de même ? [(N)on|(o)ui] " WHATUSERWANTTODO ; while [[ $$ANSWERISCORRECT == "no" ]] ; do if [[ $$WHATUSERWANTTODO == "o" ]]; then ${PRINT} ${PROCNAME}.pdf ; ANSWERISCORRECT="yes" ; elif [[ $$WHATUSERWANTTODO == "n" ]]; then echo "Fin de la production. Il n’y a rien à faire." ; ANSWERISCORRECT="yes" ; else read -p "La réponse « $$WHATUSERWANTTODO » est inconue. Veuillez saisir une réponse valide [(N)on|(o)ui] " WHATUSERWANTTODO ; fi ; done
endif

########################################################################
# Traitement des arguments de nétoyage                                 #
########################################################################

archive:
	tar --gzip --create --verbose --file ${NAME}.tar.gz `ls | grep --line-regexp --file=archivedfiles | tr '\n' ' '` # N’archiver que les fichiers déffinits dans la variable `$ARCHIVED`.

clean:
	for f in `ls | grep --extended-regexp  "(^${NAME}(-Ed\.-(sav|com)|)((-agressif|)(-imprim|)(-NB|))(\.(aux|bbl|blg|glg|glo|gls|ist|log|out|run\.xml|idx|lof|toc)|-blx\.bib)|*\.tex\.project\.vim)"` ; do echo Suppression de $$f ; rm $$f ; done ;#
	for f in `ls | grep --extended-regexp  ".*(\~|\.orig)"` ; do echo Suppression de $$f ; rm $$f ; done ;#

mrproper:
	make clean;#
	for f in `ls | grep --extended-regexp  "^${NAME}(-Ed.-(sav|com)|)((-agressif|)(-imprim|)(-NB|))\.pdf"` ; do echo Suppression de $$f ; rm $$f ; done
