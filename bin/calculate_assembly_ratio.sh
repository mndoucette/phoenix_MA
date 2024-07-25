#!/bin/bash 

#
# Description: script to Compare local assembly to the expected assembly size based upon taxonomy file in directory or directly given
#
# Usage: ./calculate_assembly_ratio.sh -d path_to_database_file -q report.tsv -t tax_file -s sample_name [-f \"genus species\"] -V version"
#
# Output location: Varies on contents
#
# Modules required: None
#
# Created by Nick Vlachos (nvx4@cdc.gov)
#

version=2.0 # (11/15/2023) Changed to signify adoption of CLIA minded bversioning. This version is equivalent to previous version 1.2 (08/14/2023) # 

#  Function to print out help blurb
show_help () {
	echo "Usage is ./calculate_assembly_ratio.sh -d path_to_database_file -q report.tsv -t tax_file -s sample_name [-f \"genus species\"]"
	echo "required: -d = path to specific sorted database with statistics related to entries from NCBI"
#	echo "required: -e = path to Isolate folder that needs to have Assembly and ANI folders and an isolateID.tax file"
	echo "required: -q = quast report.tsv file"
	echo "required: -x = tax file from output of determine_taxaID.sh"
	echo "required: -s = sample_name"
	echo "optional: -f = give a specific taxonomy to compare against in the database"
	echo "optional: -V = print version and exit"
	echo ""
	echo "version: ${version}"
}

# Parse command line options
options_found=0
while getopts ":h?d:q:x:f:s:t:V" option; do
	options_found=$(( options_found + 1 ))
	case "${option}" in
		\?)
			echo "Invalid option found: ${OPTARG}"
			show_help
			exit 0
			;;
		d)
			echo "Option -d triggered, argument = ${OPTARG}"
			db_path=${OPTARG};;
		q) #changed from e
			echo "Option -q triggered, argument = ${OPTARG}"
			quast_report=${OPTARG};;
		x)
			echo "Option -x triggered, argument = ${OPTARG}"
			tax_file=${OPTARG};; # comes from determine_taxID.sh
		f)
			echo "Option -f triggered, argument = ${OPTARG}"
			force="true"
			in_genus=$(echo "${OPTARG^}" | cut -d' ' -f1)
			in_species=$(echo "${OPTARG,,}" | cut -d' ' -f2);;
		s)
			echo "Option -s triggered, argument = ${OPTARG}"
			sample_name=${OPTARG};;
		t)
			echo "Option -t triggered"
			terra=${OPTARG};;
		V)
			show_version="True";;
		:)
			echo "Option -${OPTARG} requires as argument";;
		h)
			show_help
			exit 0
			;;
	esac
done

# Show help info for when no options are given
if [[ "${options_found}" -eq 0 ]]; then
	echo "No options found"
	show_help
	exit
fi

# set the correct path for bc - needed for terra
if [[ $terra = "terra" ]]; then
	bc_path=/opt/conda/envs/phoenix/bin/bc
else
	bc_path=bc
fi

if [[ "${show_version}" = "True" ]]; then
	echo "calculate_assembly_ratio.sh: ${version}"
	exit
fi

taxid="NA"
stdev="NA"
stdevs="NA"
assembly_length='NA'
expected_length='NA'
total_tax='NA'
taxid='NA'

# Accounts for manual entry or passthrough situations
if [[ -f "${db_path}" ]]; then
	#Clean up database so the name doesn't start with lowercase letter (change to uppercase) and remove brackets
	sed 's/^\(.\)/\U\1/' $db_path > db_path_update.txt
	sed -i 's/\[//' db_path_update.txt
	sed -i 's/\]//' db_path_update.txt
	NCBI_ratio=db_path_update.txt
	NCBI_ratio_date=$(echo "${db_path}" | rev | cut -d'_' -f1 | cut -d'.' -f2 | rev) #expects date
#	NCBI_ratio_date="20210819"
else
	echo "No ratio DB, exiting"
	echo -e "Tax: ${total_tax}\nNCBI_TAXID: ${taxid}\nSpecies_StDev: ${stdev}\nIsolate_St.Devs: ${stdevs}\nActual_length: ${assembly_length}\nExpected_length: ${expected_length}\nRatio: -2" >  "${sample_name}_Assembly_ratio_${NCBI_ratio_date}.txt"
	echo -e "Tax: No genus Found	No species found\nNCBI_TAXID: No Match Found\nSpecies_GC_StDev: No Match Found\nSpecies_GC_Min: No Match Found\nSpecies_GC_Max: No Match Found\nSpecies_GC_Mean: No Match Found\nSpecies_GC_Count: No Match Found\nSample_GC_Percent: No Match Found" >  "${sample_name}_GC_content_${NCBI_ratio_date}.txt"
	exit
fi

# Checks for correct parameter s and sets appropriate outdatadirs
#if [[ ! -z "${epath}" ]]; then
#	if [[ "${epath: -1}" == "/" ]]; then
#		epath=${epath::-1}
#	fi
#	OUTDATADIR="${epath}"
#	project=$(echo "${epath}" | rev | cut -d'/' -f2 | rev)
#	sample_name=$(echo "${epath}" | rev | cut -d'/' -f1 | rev)
#fi

#echo -e "Checking if directories exist:\nIsolate:${OUTDATADIR}\nANI:${OUTDATADIR}/ANI\nAssembly:${OUTDATADIR}/Assembly"
# Checks for proper argumentation
#if [[ ! -d "${OUTDATADIR}" ]] || [[ ! -d "${OUTDATADIR}/ANI" ]] || [[ ! -d "${OUTDATADIR}/Assembly" ]]; then
#	echo "No sample (or ANI or Assembly) folder exist, exiting"
#	exit 1
#fi

#echo "Checking if Assembly_stats exists: ${OUTDATADIR}/quast/report.tsv"
#if [[ -f "${OUTDATADIR}/quast/report.tsv" ]]; then
#	assembly_length=$(sed -n '16p' "${OUTDATADIR}/quast/report.tsv" | sed -r 's/[\t]+/ /g' | cut -d' ' -f3)
echo "Checking if quast Assembly_stats exists: ${quast_report}"
if [[ -f "${quast_report}" ]]; then
	assembly_length=$(sed -n '16p' "${quast_report}" | sed -r 's/[\t]+/ /g' | cut -d' ' -f3)
	sample_gc_percent=$(sed -n '17p' "${quast_report}" | sed -r 's/[\t]+/ /g' | cut -d' ' -f3)
# Another method if we start seeing too many failures with main method
#elif
else
	echo "No quast exists, cannot continue"
	echo -e "Tax: ${total_tax}\nNCBI_TAXID: ${taxid}\nSpecies_StDev: ${stdev}\nIsolate_St.Devs: ${stdevs}\nActual_length: ${assembly_length}\nExpected_length: ${expected_length}\nRatio: -2" >  "${sample_name}_Assembly_ratio_${NCBI_ratio_date}.txt"
	echo -e "Tax: No genus Found	No species found\nNCBI_TAXID: No Match Found\nSpecies_GC_StDev: No Match Found\nSpecies_GC_Min: No Match Found\nSpecies_GC_Max: No Match Found\nSpecies_GC_Mean: No Match Found\nSpecies_GC_Count: No Match Found\nSample_GC_Percent: No Match Found" >  "${sample_name}_GC_content_${NCBI_ratio_date}.txt"
	exit
fi
counter=0

if [[ ! "${force}" ]]; then
	echo "Checking if Tax summary exists: ${tax_file}"
	if  [[ -f "${tax_file}" ]]; then
		# All tax files seem to have an extra empty line. To avoid messing anything else up, we'll deal with it as is
		genus=$(head -n7 "${tax_file}" | tail -n1 | cut -d'	' -f2)
		if [[ "${genus}" = "" ]]; then
			genus="No genus found"
		fi
		species=$(head -n8 "${tax_file}" | tail -n1 | cut -d'	' -f2)
		# handling species with sp in the name.
		if [[ $species == *sp.* ]]; then
			# If yes, remove a space after "sp."
			species="${species/sp. /sp.}"
			#make sure the letters after sp. are in caps
			species=$(echo "$species" | sed -E 's/(sp\.)([a-zA-Z]+)/\1\U\2/')
			#change spaces to - to be inline with how the NCBI assembly stats file is made
			species="${species// /-}"
		fi
		if [[ "${species}" = "" ]]; then
			species="No species found"
		fi
		total_tax="${genus} ${species}"
		#echo "${genus} ${species}"
	else
		echo "No Tax file to find accession for lookup, exiting"
		exit
	fi
else
	genus="${in_genus}"
	species="${in_species}"
	total_tax="${genus} ${species}	(selected manually)"
fi


while IFS='' read -r line; do
	IFS=$'\t' read -a arr_line <<< "$line"
	#echo "${arr_line}"
	#echo  "${genus} ${species} vs ${arr_line[0]}"
	# convert all variables to all lowercase for a case agnostic search
	if [[ "${genus,,} ${species,,}" = "${arr_line[0],,}" ]]; then
		# if sp. is in the name then 
		taxid="${arr_line[19]}"
		if [ "${taxid}" = -2 ]; then
			taxid="No mode available when determining tax id"
		elif [ "${taxid}" = -1 ]; then
			taxid="No tax id given or empty when making lookup"
		fi
		expected_length=$(echo "scale=0; 1000000 * ${arr_line[4]} / 1 " | $bc_path | cut -d'.' -f1)
		reference_count="${arr_line[6]}"
		stdev=$(echo "scale=4; 1000000 * ${arr_line[5]} /1 " | $bc_path | cut -d"." -f1)
		if [[ "${reference_count}" -lt 10 ]]; then
			stdev="Not calculated on species with n<10 references"
			stdevs="NA"
		else
			if [[ "${assembly_length}" -gt "${expected_length}" ]]; then
				bigger="${assembly_length}"
				smaller="${expected_length}"
			else
				smaller="${assembly_length}"
				bigger="${expected_length}"
			fi
			stdevs=$(echo "scale=4 ; ( ${bigger} - ${smaller} ) / ${stdev}" | $bc_path )
		fi
		#GC content
		gc_min="${arr_line[7]}"
		gc_max="${arr_line[8]}"
		gc_mean="${arr_line[10]}"
		gc_count="${arr_line[12]}"
		if [[ "${gc_count}" -lt 10 ]]; then
			gc_stdev="Not calculated on species with n<10 references"
		else
			gc_stdev="${arr_line[11]}"
		fi
		echo -e "Tax: ${total_tax}\nNCBI_TAXID: ${taxid}\nSpecies_GC_StDev: ${gc_stdev}\nSpecies_GC_Min: ${gc_min}\nSpecies_GC_Max: ${gc_max}\nSpecies_GC_Mean: ${gc_mean}\nSpecies_GC_Count: ${gc_count}\nSample_GC_Percent: ${sample_gc_percent}" >  "${sample_name}_GC_content_${NCBI_ratio_date}.txt"



		break
	#elif [[ "${genus} ${species}" < "${arr_line[0]}" ]]; then
	elif [[ "${genus:0:1}" < "${arr_line[0]:0:1}" ]]; then
		break
	fi
done < "${NCBI_ratio}"
#echo "looked in ${NCBI_ratio}"

#echo "${expected_length}-${assembly_length}"

if [[ ${expected_length} = "NA" ]] || [[ -z ${expected_length} ]]; then
	echo "No expected length was found to compare to"
	echo -e "Tax: ${total_tax}\nNCBI_TAXID: ${taxid}\nSpecies_StDev: NA\nIsolate_St.Devs: NA\nActual_length: ${assembly_length}\nExpected_length: NA\nRatio: -1" >  "${sample_name}_Assembly_ratio_${NCBI_ratio_date}.txt"
	echo -e "Tax: ${total_tax}\nNCBI_TAXID: ${taxid}\nSpecies_GC_StDev: No Match Found\nSpecies_GC_Min: No Match Found\nSpecies_GC_Max: No Match Found\nSpecies_GC_Mean: No Match Found\nSpecies_GC_Count: No Match Found\nSample_GC_Percent: No Match Found" >  "${sample_name}_GC_content_${NCBI_ratio_date}.txt"
	exit
elif [[ ${assembly_length} = "NA" ]] || [[ -z ${assembly_length} ]]; then
	echo "No assembly length was found to compare with"
	echo -e "Tax: ${total_tax}\nNCBI_TAXID: ${taxid}\nSpecies_StDev: ${stdev}\nIsolate_St.Devs: NA\nActual_length: NA\nExpected_length: ${expected_length}\nRatio: -2" >  "${sample_name}_Assembly_ratio_${NCBI_ratio_date}.txt"
	echo -e "Tax: ${total_tax}\nNCBI_TAXID: ${taxid}\nSpecies_GC_StDev: ${gc_stdev}\nSpecies_GC_Min: ${gc_min}\nSpecies_GC_Max: ${gc_max}\nSpecies_GC_Mean: ${gc_mean}\nSpecies_GC_Count: ${gc_count}\nSample_GC_Percent: NA" >  "${sample_name}_GC_content_${NCBI_ratio_date}.txt"
	exit
fi

ratio=$(echo "scale=6; ${assembly_length} / ${expected_length}" | $bc_path | awk '{printf "%.4f", $0}')

echo -e "Actual - ${assembly_length}\nExpected - ${expected_length}\nRatio - ${ratio}\nSpecies_St.Devs - ${stdev}\nIsolate_St.Dev - ${stdevs}"

echo -e "Tax: ${total_tax}\nNCBI_TAXID: ${taxid}\nSpecies_St.Dev: ${stdev}\nIsolate_St.Devs: ${stdevs}\nActual_length: ${assembly_length}\nExpected_length: ${expected_length}\nRatio: ${ratio}" >  "${sample_name}_Assembly_ratio_${NCBI_ratio_date}.txt"
