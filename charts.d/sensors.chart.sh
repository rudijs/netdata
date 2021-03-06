#!/bin/sh

# sensors docs
# https://www.kernel.org/doc/Documentation/hwmon/sysfs-interface

# if this chart is called X.chart.sh, then all functions and global variables
# must start with X_

sensors_sys_dir="/sys/devices"
sensors_sys_depth=10
sensors_source_update=1

# _update_every is a special variable - it holds the number of seconds
# between the calls of the _update() function
sensors_update_every=

sensors_find_all_files() {
	find $1 -maxdepth $sensors_sys_depth -name \*_input -o -name temp 2>/dev/null
}

sensors_find_all_dirs() {
	sensors_find_all_files $1 | while read
	do
		dirname $REPLY
	done | sort -u
}

# _check is called once, to find out if this chart should be enabled or not
sensors_check() {

	# this should return:
	#  - 0 to enable the chart
	#  - 1 to disable the chart

	[ ! -z "$( sensors_find_all_files $sensors_sys_dir )" ] && return 0
	return 1
}

sensors_check_files() {
	# we only need sensors that report a non-zero value

	local f= v=
	for f in $*
	do
		[ ! -f "$f" ] && continue

		v="$( cat $f )"
		v=$(( v + 1 - 1 ))
		[ $v -ne 0 ] && echo "$f" && continue
		
		echo >&2 "charts.d: sensors: $f gives zero values"
	done
}

sensors_check_temp_type() {
	# valid temp types are 1 to 6
	# disabled sensors have the value 0

	local f= t= v=
	for f in $*
	do
		t=$( echo $f | sed "s|_input$|_type|g" )
		[ "$f" = "$t" ] && echo "$f" && continue
		[ ! -f "$t" ] && echo "$f" && continue

		v="$( cat $t )"
		v=$(( v + 1 - 1 ))
		[ $v -ne 0 ] && echo "$f" && continue

		echo >&2 "charts.d: sensors: $f is disabled"
	done
}

# _create is called once, to create the charts
sensors_create() {
	local path= dir= name= x= file= lfile= labelname= labelid= device= subsystem= id= type= mode= files= multiplier= divisor=

	# we create a script with the source of the
	# sensors_update() function
	# - the highest speed we can achieve -
	[ $sensors_source_update -eq 1 ] && echo >$TMP_DIR/sensors.sh "sensors_update() {"

	for path in $( sensors_find_all_dirs $sensors_sys_dir | sort -u )
	do
		dir=$( basename $path )
		device=
		subsystem=
		id=
		type=
		name=

		[ -h $path/device ] && device=$( readlink -f $path/device )
		[ ! -z "$device" ] && device=$( basename $device )
		[ -z "$device" ] && device="$dir"

		[ -h $path/subsystem ] && subsystem=$( readlink -f $path/subsystem )
		[ ! -z "$subsystem" ] && subsystem=$( basename $subsystem )
		[ -z "$subsystem" ] && subsystem="$dir"

		[ -f $path/name ] && name=$( cat $path/name )
		[ -z "$name" ] && name="$dir"

		[ -f $path/type ] && type=$( cat $path/type )
		[ -z "$type" ] && type="$dir"

		id="$( fixid "$device.$subsystem.$dir" )"

		echo >&2 "charts.d: sensors: on path='$path', dir='$dir', device='$device', subsystem='$subsystem', id='$id', name='$name'"

		for mode in temperature voltage fans power current energy humidity
		do
			files=
			multiplier=1
			divisor=1
			algorithm="absolute"

			case $mode in
				temperature)
					files="$( ls $path/temp*_input 2>/dev/null; ls $path/temp 2>/dev/null )"
					files="$( sensors_check_files $files )"
					files="$( sensors_check_temp_type $files )"
					[ -z "$files" ] && continue
					echo "CHART sensors.temp_$id '' '$name Temperature' 'Celcius' '$device' '' line 6000 $sensors_update_every"
					echo >>$TMP_DIR/sensors.sh "echo \"BEGIN sensors.temp_$id \$1\""
					divisor=1000
					;;

				voltage)
					files="$( ls $path/in*_input 2>/dev/null )"
					files="$( sensors_check_files $files )"
					[ -z "$files" ] && continue
					echo "CHART sensors.volt_$id '' '$name Voltage' 'Volts' '$device' '' line 6001 $sensors_update_every"
					echo >>$TMP_DIR/sensors.sh "echo \"BEGIN sensors.volt_$id \$1\""
					divisor=1000
					;;

				current)
					files="$( ls $path/curr*_input 2>/dev/null )"
					files="$( sensors_check_files $files )"
					[ -z "$files" ] && continue
					echo "CHART sensors.curr_$id '' '$name Current' 'Ampere' '$device' '' line 6002 $sensors_update_every"
					echo >>$TMP_DIR/sensors.sh "echo \"BEGIN sensors.curr_$id \$1\""
					divisor=1000
					;;

				power)
					files="$( ls $path/power*_input 2>/dev/null )"
					files="$( sensors_check_files $files )"
					[ -z "$files" ] && continue
					echo "CHART sensors.power_$id '' '$name Power' 'Watt' '$device' '' line 6003 $sensors_update_every"
					echo >>$TMP_DIR/sensors.sh "echo \"BEGIN sensors.power_$id \$1\""
					divisor=1000000
					;;

				fans)
					files="$( ls $path/fan*_input 2>/dev/null )"
					files="$( sensors_check_files $files )"
					[ -z "$files" ] && continue
					echo "CHART sensors.fan_$id '' '$name Fans Speed' 'Rotations / Minute' '$device' '' line 6004 $sensors_update_every"
					echo >>$TMP_DIR/sensors.sh "echo \"BEGIN sensors.fan_$id \$1\""
					;;

				emergy)
					files="$( ls $path/energy*_input 2>/dev/null )"
					files="$( sensors_check_files $files )"
					[ -z "$files" ] && continue
					echo "CHART sensors.energy_$id '' '$name Energy' 'Joule' '$device' '' areastack 6005 $sensors_update_every"
					echo >>$TMP_DIR/sensors.sh "echo \"BEGIN sensors.energy_$id \$1\""
					algorithm="incremental"
					divisor=1000000
					;;

				humidity)
					files="$( ls $path/humidity*_input 2>/dev/null )"
					files="$( sensors_check_files $files )"
					[ -z "$files" ] && continue
					echo "CHART sensors.humidity_$id '' '$name Humidity' 'Percent' '$device' '' line 6006 $sensors_update_every"
					echo >>$TMP_DIR/sensors.sh "echo \"BEGIN sensors.humidity_$id \$1\""
					divisor=1000
					;;

				*)
					continue
					;;
			esac

			for x in $files
			do
				file="$x"
				fid="$( fixid "$file" )"
				lfile="$( basename $file | sed "s|_input$|_label|g" )"
				labelname="$( basename $file | sed "s|_input$||g" )"

				if [ ! "$path/$lfile" = "$file" -a -f "$path/$lfile" ]
					then
					labelname="$( cat "$path/$lfile" )"
				fi

				echo "DIMENSION $fid '$labelname' $algorithm $multiplier $divisor"
				echo >>$TMP_DIR/sensors.sh "printf \"SET $fid = \"; cat $file "
			done

			echo >>$TMP_DIR/sensors.sh "echo END"
		done
	done

	[ $cpufreq_source_update -eq 1 ] && echo >>$TMP_DIR/sensors.sh "}"
	# cat >&2 $TMP_DIR/sensors.sh

	# ok, load the function sensors_update() we created
	[ $sensors_source_update -eq 1 ] && . $TMP_DIR/sensors.sh

	return 0
}

# _update is called continiously, to collect the values
sensors_update() {
	# the first argument to this function is the microseconds since last update
	# pass this parameter to the BEGIN statement (see bellow).

	# do all the work to collect / calculate the values
	# for each dimension
	# remember: KEEP IT SIMPLE AND SHORT

	[ $sensors_source_update -eq 0 ] && . $TMP_DIR/sensors.sh $1

	return 0
}

