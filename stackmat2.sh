#!/bin/bash

# Use gdate on macOS
if command -v gdate &> /dev/null; then
    DATE_CMD="gdate"
else
    DATE_CMD="date"
fi

format_time() {
    local hundredths=$1
    if [[ "$hundredths" == "DNF" ]]; then
        echo "DNF"
        return
    fi
    local total_seconds=$((hundredths / 100))
    local minutes=$((total_seconds / 60))
    local seconds=$((total_seconds % 60))
    local hsecs=$((hundredths % 100))
    printf "%02d:%02d.%02d" "$minutes" "$seconds" "$hsecs"
}

average_of() {
    local count=$1
    shift
    local times=("$@")
    local valid=()

    # Collect the last N non-DNF solves
    for ((i=${#times[@]}-1; i>=0 && ${#valid[@]}<count; i--)); do
        [[ "${times[i]}" != "DNF" ]] && valid+=("${times[i]}")
    done

    if (( ${#valid[@]} < count )); then
        echo "N/A"
        return
    fi

    IFS=$'\n' sorted=($(sort -n <<<"${valid[*]}"))
    unset IFS

    local sum=0
    for ((i=1; i<count-1; i++)); do
        sum=$((sum + sorted[i]))
    done

    local avg=$((sum / (count - 2)))
    echo "$avg"
}

# Global arrays
solves_raw=()
solves_display=()

clear
echo "StackMat Virtual Timer 2.0"
echo "Press SPACE to start, again to stop. Ctrl+C to exit."

while true; do
    echo -n "Waiting for space to start..."
    while IFS= read -rsn1 key; do
        [[ $key == " " ]] && break
    done

    echo -e "\nStarted. Press space again to stop."
    start_ns=$($DATE_CMD +%s%N)

    (
        while :; do
            current_ns=$($DATE_CMD +%s%N)
            diff=$((current_ns - start_ns))
            hsec=$((diff / 10000000))
            formatted=$(format_time "$hsec")
            echo -ne "\rTime: $formatted    "
            sleep 0.1
        done
    ) &
    timer_pid=$!

    while IFS= read -rsn1 key; do
        [[ $key == " " ]] && break
    done

    kill "$timer_pid" &> /dev/null
    wait "$timer_pid" 2>/dev/null

    end_ns=$($DATE_CMD +%s%N)
    elapsed_hsec=$(((end_ns - start_ns) / 10000000))

    echo -e "\nWas the last solve a DNF? (y/n)"
    read -r dnf
    if [[ "$dnf" == "y" || "$dnf" == "Y" ]]; then
        solves_raw+=("DNF")
        time_label="DNF"
    else
        echo "Did the last solve have a +2 penalty? (y/n)"
        read -r penalty
        if [[ "$penalty" == "y" || "$penalty" == "Y" ]]; then
            elapsed_hsec=$((elapsed_hsec + 20))
            time_label="$(format_time "$elapsed_hsec") (+2)"
        else
            time_label="$(format_time "$elapsed_hsec")"
        fi
        solves_raw+=("$elapsed_hsec")
    fi

    solves_display+=("$time_label")
    echo "Solve ${#solves_display[@]}: $time_label"

    ao5_raw=$(average_of 5 "${solves_raw[@]}")
	ao12_raw=$(average_of 12 "${solves_raw[@]}")

	if [[ "$ao5_raw" == "N/A" ]]; then
    	ao5_disp="N/A"
	else
    	ao5_disp=$(format_time "$ao5_raw")
	fi

	if [[ "$ao12_raw" == "N/A" ]]; then
    	ao12_disp="N/A"
	else
    	ao12_disp=$(format_time "$ao12_raw")
	fi


    echo "ao5: $ao5_disp"
    echo "ao12: $ao12_disp"

    timestamp=$(date +%m/%d/%Y)
    echo "date: $timestamp solve: $time_label ao5: $ao5_disp ao12: $ao12_disp" >> ~/time.txt
    echo
done
