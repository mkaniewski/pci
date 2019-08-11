#!/bin/sh

# Read the PCIe device extended configuration by directly acessing a CPU
# physical memory space.
#
# Similar result can be achived using:
# - On Linux: lspci -xxxx -s bus:device:function
# - On FreeBSD: pciconf -r pci0:0:9:0 0x00:0xFFF

# Adress under which PCIe extended configuration is placed. It can be obtained
# from the PCIEXBAR register or from an ACPI MCFG table.
PCIE_CONF_BASE_ADDR=0xB0000000

usage() {
	echo "Usage: ${0} bus:device:function length"  >&2
	echo "" >&2
	echo "Example: ${0} 0:9:0 256"  >&2
	exit 1
}

die() {
	echo "[ERROR]: ${@}" >&2
	exit 1
}

main() {
	local addr bus conf device err function length pcitriple tmpfile

	pcitriple="${1}"
	length="${2}"

	[ -n "${pcitriple}" ] || usage
	[ -n "${length}" ] || usage

	bus="$(echo ${pcitriple} | cut -d ':' -f1)"
	device="$(echo ${pcitriple} | cut -d ':' -f2)"
	function="$(echo ${pcitriple} | cut -d ':' -f3)"

	[ -n "${bus}" ] || [ -n "${device}" ] || [ -n "${function}" ] || usage

	case "$(uname -s)" in
	"Linux")
		MEMDEV="/dev/fmem"
		if [ ! -e "${MEMDEV}" ]; then
			die "On Linux /dev/fmem must be available to access entire memory space."
		fi
		;;
	"FreeBSD")
		MEMDEV="/dev/mem"
		;;
	*)
		die "Unexpected system: '$(uname -s)'."
		;;
	esac

	# PCIe configuration space consists of:
	# 256 buses * 32 devices * 8 function * 4 KB configuration = 256 MB
	# therefore we know that there is:
	# - 1 MB (0x10000 bytes) for every bus
	# - 32 KB (0x8000 bytes) for every device
	# - 4 KB (0x1000 bytes) for every function.
	addr=$((PCIE_CONF_BASE_ADDR + bus * 0x100000 + dev * 0x8000 + func * 0x1000))

	tmpfile="$(mktemp)"

	err="$(dd if="${MEMDEV}" bs=1 skip="${addr}" count=${length} of="${tmpfile}" 2>&1)"
	if [ "${?}" -ne 0 ]; then
		rm "${tmpfile}"
		die "Unable to read addr ${addr} from ${MEMDEV}: ${err}."
	fi

	echo "Read ${length} bytes from address ${adddr}."

	xxd "${tmpfile}"
	rm "${tmpfile}"
}

main ${@}
