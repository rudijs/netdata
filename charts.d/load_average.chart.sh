#!/bin/sh

load_average_update_every=

load_average_check() {
	# this should return:
	#  - 0 to enable the chart
	#  - 1 to disable the chart

	return 0
}

load_average_create() {
	# create a chart with 3 dimensions
cat <<EOF
CHART example.load '' "System Load Average" "load" load load line 500 $load_average_update_every
DIMENSION load1 '1 min' absolute 1 100
DIMENSION load5 '5 mins' absolute 1 100
DIMENSION load15 '15 mins' absolute 1 100
EOF

	return 0
}

load_average_update() {
	# do all the work to collect / calculate the values
	# for each dimension
	# remember: KEEP IT SIMPLE AND SHORT

	# here we parse the system average load
	# it is decimal (with 2 decimal digits), so we remove the dot and
	# at the definition we have divisor = 100, to have the graph show the right value
	loadavg="`cat /proc/loadavg | sed -e "s/\.//g"`"
	load1=`echo $loadavg | cut -d ' ' -f 1`
	load5=`echo $loadavg | cut -d ' ' -f 2`
	load15=`echo $loadavg | cut -d ' ' -f 3`

	# write the result of the work.
	cat <<VALUESEOF
BEGIN example.load
SET load1 = $load1
SET load5 = $load5
SET load15 = $load15
END
VALUESEOF

	return 0
}

