globals [
  Minute
  Hour
  Day
  day?
  facilities
  roads
  speed                    ; patches / minute
  infection-distance
  cum-infected
  cum-symptomatic
  cum-asymptomatic
  cum-severe
  cum-critical
  cum-dead
  cum-recovered
  numtents
  patch-capacity
  patch-length
  shelters                ; the initial tents, used to manage the households.
  infection-locations
  show-colors?
]

breed [refugees refugee]
breed [tents tent]
breed [latrines latrine]
breed [waterpoints waterpoint]
breed [foodpoints foodpoint]
breed [hc-facs hc-fac]
breed [COVID-facilities COVID-facility]

tents-own [ myhome            ; patch of home
            food-supply
            latrine-time
            water-time
            healthcare-time
            food-time
            walker?
            household         ; consists initially of 5 or 7 members: child (<18) / adult (18-60) / elderly (60+)
            sick-household    ; all households members that are sick at home (also pre- and a-symptomatic)

  ;;;; this is what walkers need.
          ;  myhome
            my-age            ; child / adult / elderly
            compliant?        ; compliant to policy regulations? true / false
            infected?         ; true / false
            destination       ; myhome / facility / none
            occupancy         ; free / busy / in-hospital
            infection         ; susceptible / infected / pre-symptomatic / asymptomatic / symptomatic / severely-symptomatic / critical / recovered
            infection-perception ; healthy / infectious / recovered
            time-until-next-stage  ; the number of days an agent is in a certain stage of COVID-19.
            next-stage        ; the next stage of COVID-19 (at setup, this is "infected")
            queue-time        ; time the agent has spent waiting in line for a facility
            destination-when-infected ; where the refugee was heading and what its queue-time was when getting infected
]

latrines-own    [ waiting-list serving-time initial-serving-time ]
waterpoints-own [ waiting-list serving-time initial-serving-time ]
foodpoints-own  [ waiting-list serving-time initial-serving-time ]
hc-facs-own     [ waiting-list serving-time initial-serving-time ]
COVID-facilities-own [consult-capacity bed-capacity IC-capacity   ; available (free) capacity in the COVID-19 facility
                      in-treatment in-IC                          ; occupied capacity (number of patients) in the COVID-19 facility
                     ; initial-consult-time
                     ]
patches-own [ popularity ]

;;;;;; how to address all facilities:
;;;;;; foreach facilities [[the-turtle] -> ask the-turtle [print [who] of self] ]


to setup
  clear-all
  reset-ticks
;  create-facilities-old
  ifelse poor-conditions? [create-facilities-poor][create-facilities-good]
  set show-colors? True

  create-shelter-locations
  set numtents (count tents * household-size)
  set day? False
  set shelters turtle-set [self] of tents

  ; determine travel speed and queue space:
  if plotsize-shelters = "12,5 m2" [set patch-length 1.68 set patch-capacity 12 ]
  if plotsize-shelters = "25 m2"  [ set patch-length 2.38 set patch-capacity 20 ]
  if plotsize-shelters = "50 m2"  [ set patch-length 3.37 set patch-capacity 42 ]
  if plotsize-shelters = "100 m2" [ set patch-length 4.77 set patch-capacity 90 ]
  set infection-distance (1.5 / patch-length)
  set speed 83.33 / patch-length   ; 83.33 is a normal walking speed in meters per minute. Patch-length is in meters.

end


to create-shelter-locations
  if block-size = "60 shelters" [setup4blocks]
  if block-size = "120 shelters" [setup2blocks]
  if block-size = "test-mode: few shelters" [create-a-few-tents]
  ask patches with [pcolor = white] [set popularity 100]

  ask tents [
    set color blue
    set shape "campsite"
    set size 1

    move-to one-of patches with [pcolor = black]
    while [ any? other tents-here] [move-to one-of patches with [pcolor = black]]
    set myhome patch-here
    set occupancy "free"
    set infection "susceptible"
    set infection-perception "healthy"
    set time-until-next-stage 0
    set next-stage "infected"
    set infected? False
    set destination "Home"
    set walker? false

    set water-time (random 13) + 6   ; fetch water during day hours (between 6 and latest 18:00
    set healthcare-time (random 8) + 7   ; seek healthcare during opening-hours of facility (between 7:00 and latest 15:00
    set food-time (random 6) + 7      ; walk to food distribution in mornings between 7:00 and 13:00
;    set food-supply random 8         ; food supply lasts 28 days.
;    set latrine-counter random 8     ; 10 toilet visits per hh per day, if the day hours are from 6 - 23:30
    determine-households

    set queue-time 0 ]
end

to setup2blocks
  ask patches with [(pxcor >= max-pxcor ) or (pxcor <= min-pxcor + 1) or (pycor >= max-pycor - 1) or (pycor <= min-pycor + 1)]
  [set pcolor white]

  let half (max-pycor / 2) ; adapted from pxcor to pycor
  ask patches with [(pxcor = floor half) or (pxcor = ceiling half) or (pycor = floor half) or (pycor = ceiling half) ][set pcolor white]

  ask patches with [(pxcor mod 2 = 1) and (pycor mod 2 = 1) and (pcolor = black)] [ sprout-tents 1]
  if (count tents - 240 > 0) [ask max-n-of 2 tents [who] [die]]

end

to setup4blocks
  ask patches with [(pxcor >= max-pxcor ) or (pxcor <= min-pxcor ) or (pycor >= max-pycor - 1) ] ; adapted for half camp
  [set pcolor white]

 ; let half (max-pxcor / 2)
  let quarter (max-pycor / 4)
  ask patches with [(pycor mod (floor quarter) = 0) ][set pcolor white]

  ask patches with [(pxcor mod 2 = 1) and (pycor mod 2 = 0) and (pcolor = black)] [ sprout-tents 1 ;[set size 2 set shape "campsite"]
  ]
end

to create-a-few-tents
  ask patches with [(pxcor >= max-pxcor ) or (pxcor <= min-pxcor ) or (pycor >= max-pycor - 1) ] ; adapted for half camp
  [set pcolor white]

 ; let half (max-pxcor / 2)
  let quarter (max-pycor / 4)
  ask patches with [(pycor mod (floor quarter) = 0) ][set pcolor white]
  ask n-of 20 patches with [pcolor = black] [sprout-tents 1]

end

to determine-households
  let profile random 5 + 1
  if household-size = 7 [
  ifelse profile = 1 [
    set household shuffle (list "elderly" "adult" "adult" "adult" "child" "child" "child")] [
  ifelse profile = 2 [
    set household shuffle (list "elderly" "adult" "child" "child" "child" "child" "child")] [
  ifelse profile = 3 [
    set household shuffle (list "adult" "adult" "adult" "child" "child" "child" "child")] [
  ifelse profile = 4 [
    set household shuffle (list "elderly" "adult" "adult" "child" "child" "child" "child")] [
  ; if profile = 5
    set household shuffle (list "adult" "adult" "adult" "adult" "child" "child" "child")] ] ] ] ]

  if household-size = 5 [
    ifelse profile = 1 [
    set household shuffle (list "elderly" "adult" "adult" "child" "child")] [
  ifelse profile = 2 [
    set household shuffle (list "adult" "adult" "adult" "child" "child")] [
  ifelse profile = 3 [
    set household shuffle (list "elderly" "adult" "child" "child" "child")] [
  ifelse profile = 4 [
    set household shuffle (list "adult" "adult" "child" "child" "child")] [
  ; if profile = 5
    set household shuffle (list "adult" "adult" "child" "child" "child")] ] ] ] ]
  set sick-household []
end

to create-facilities-good  ; depending on the chooser in the Model Interface, a large amount of facilities is created, or a very limited amount.
  ifelse household-size = 5
  [ create-latrines 12 [
      set shape "toilet2"
      set size 1
      set color grey
      set heading 0
      set serving-time 2
      set initial-serving-time 2 ]
    create-waterpoints 48 [
      set shape "drop"
      set size 1
      set color cyan
      set heading 0
      set serving-time 15
      set initial-serving-time 15]
    create-hc-facs 1 [
      set shape "healthcare"
      set size 1
      set color white
      set heading 0
      set serving-time 2
      set initial-serving-time 2 ]]
  ; if household-size = 7 :
  [ create-latrines 16 [
      set shape "toilet2"
      set size 1
      set color grey
      set heading 0
      set serving-time 2
      set initial-serving-time 2 ]
    create-waterpoints 48 [ ; 76 [ ;76 is too many, they can't be placed!
      set shape "drop"
      set size 1
      set color cyan
      set heading 0
      set serving-time 15
      set initial-serving-time 15 ]
    create-hc-facs 2 [
      set shape "healthcare"
      set size 1
      set color white
      set heading 0
      set serving-time 10
      set initial-serving-time 10 ]]

  ; always create 1 food distribution point
    create-foodpoints 1 [
      set shape "truck"
      set size 2
      set color grey
      set heading 0
      set serving-time 2
      set initial-serving-time 2 ]

 ; locating facilities:
  ask turtles [
    let x random 2
    ifelse x = 1 [setxy min-pxcor random-ycor] [
        setxy random-xcor max-pycor ]
    while [any? other turtles in-radius 2] [set x random 2 ifelse x = 1 [setxy min-pxcor random-ycor] [setxy random-xcor max-pycor ]]
    set waiting-list [] ]
  ; to make latrines represent a block of 10 toilets:
  ask latrines [hatch 9 []]

  ; create agentset with all facilities in there:
  set facilities (turtle-set latrines waterpoints foodpoints hc-facs)
end

to create-facilities-poor  ; depending on the chooser in the Model Interface, a large amount of facilities is created, or a very limited amount.
  ifelse household-size = 5
  [ create-latrines 5 [
      set shape "toilet2"
      set size 1
      set color grey
      set heading 0
      set serving-time 2
      set initial-serving-time 2 ]
    create-waterpoints 9 [
      set shape "drop"
      set size 1
      set color cyan
      set heading 0
      set serving-time 15
      set initial-serving-time 15]]
  ; if household-size = 7 :
  [ create-latrines 7 [
      set shape "toilet2"
      set size 1
      set color grey
      set heading 0
      set serving-time 2
      set initial-serving-time 2 ]
    create-waterpoints 9 [ ; 13 [  ; waterpoints number is not changing because the number of household remains equal.
      set shape "drop"
      set size 1
      set color cyan
      set heading 0
      set serving-time 15
      set initial-serving-time 15 ]]

  ; always create 1 HC facility and 1 food distribution point
    create-hc-facs 1 [
      set shape "healthcare"
      set size 1
      set color white
      set heading 0
      set serving-time 10
      set initial-serving-time 10 ]
    create-foodpoints 1 [
      set shape "truck"
      set size 2
      set color grey
      set heading 0
      set serving-time 2
      set initial-serving-time 2 ]
 ; locating facilities:
  ask turtles [
    let x random 2
    ifelse x = 1 [setxy min-pxcor random-ycor] [
        setxy random-xcor max-pycor ]
    while [any? other turtles in-radius 2] [set x random 2 ifelse x = 1 [setxy min-pxcor random-ycor] [setxy random-xcor max-pycor ]]
    set waiting-list [] ]
  ; to make latrines represent a block of 10 toilets:
  ask latrines [hatch 9 []]

  ; create agentset with all facilities in there:
  set facilities (turtle-set latrines waterpoints foodpoints hc-facs)
end

to create-COVID-facility
  create-COVID-facilities 1 [
    set shape "target"
    set size 2
    set heading 0
    setxy 25 24
    set bed-capacity 100
    set IC-capacity 8
 ;;; for not-severe consults:
 ;   set consult-capacity 1
 ;   set initial-consult-time 10

    ; If it needs to 'manage-queues', it must also append to the facilities list:
    ;; BUT: covid-facility currently doesn't have a waiting-list, so doesn't work as of now.
  ]
end



; go and initiate facility-usage
to go-old0309
  time-runs    ; time is running
  ;if (Hour = 5) and (Minute = 0) [ask tents with [infected? = true] [disease-progression]]   ; at 5AM, the disease progresses, potentially to the next stage
  if Minute = 0 [ask tents with [infected? = true] [disease-progression]]

  if (Day mod 28) = 1 [ ; food-delivery day
    ;; initiate food-collection
    ask shelters [ if (Hour = food-time) and (Minute = 15) [go-get-food2]]]

  if day?
   [ ;; initiate facility-usage
      if Minute = 0 [ if household-size = 5 [ask shelters [set latrine-time random 142 ]]  ; determines when they will use the toilet in this hour.
                      if household-size = 7 [ask shelters [set latrine-time random 98 ]]]
      ask shelters [ if Minute = latrine-time [go-to-latrines2]
                if (Hour = water-time) and (Minute = 0) [go-to-waterpoint2]
                if mobility != "isolation" [if (Hour = healthcare-time) and (Minute = 0) [let sick-chance random-float 1 if sick-chance < (0.388 / 7) [go-to-healthcare ] ]] ]
      ; also during isolation, people should go to normal healthcare if needed. (However, it is found that the chance of seeking healthcare is halved.
      if mobility = "isolation" [ask shelters [if (Hour = healthcare-time) and (Minute = 0) [let sick-chance random-float 1 if sick-chance < ((0.388 * 0.5) / 7) [go-to-healthcare ]]]]
                ;  Currently, healthcare-time is specified for normal healthcare usage. Not for COVID-19 care.
   new-walking
   manage-queues
   show-infections ;; at any moment of the day, people show their infection status by color. Can be ignored by setting show-colors? False
   infect
  ]
  tick
end

to go ;; made 03-09 to solve potential error.
  time-runs    ; time is running
  ;if (Hour = 5) and (Minute = 0) [ask tents with [infected? = true] [disease-progression]]   ; at 5AM, the disease progresses, potentially to the next stage
  if Minute = 0 [ask tents with [infected? = true] [disease-progression]]

  if (Day mod 28) = 1 [ ; food-delivery day
    ;; initiate food-collection
    ask shelters [ if (Hour = food-time) and (Minute = 15) [go-get-food2]]]

  if day?
   [ ;; initiate facility-usage
      if Minute = 0 [ if household-size = 5 [ask shelters [set latrine-time (random 142 + 2) ;; determines when they will use the toilet in this hour.
        while [latrine-time = 15] [set latrine-time (random 142 + 2)] ]]  ;; if latrine-time is 15, it can cause friction with food-time.
                      if household-size = 7 [ask shelters [set latrine-time (random 98 + 2)
          while [latrine-time = 15] [set latrine-time (random 98 + 2) ]]]]
      ask shelters [ if Minute = latrine-time [go-to-latrines2]
                if (Hour = water-time) and (Minute = 0) [go-to-waterpoint2]
                if mobility != "isolation" [if (Hour = healthcare-time) and (Minute = 1) [let sick-chance random-float 1 if sick-chance < (0.388 / 7) [go-to-healthcare ] ]] ]
      ; also during isolation, people should go to normal healthcare if needed. (However, it is found that the chance of seeking healthcare is halved.
      if mobility = "isolation" [ask shelters [if (Hour = healthcare-time) and (Minute = 1) [let sick-chance random-float 1 if sick-chance < ((0.388 * 0.5) / 7) [go-to-healthcare ]]]]
                ;  Currently, healthcare-time is specified for normal healthcare usage. Not for COVID-19 care.
   new-walking
   manage-queues
   show-infections ;; at any moment of the day, people show their infection status by color. Can be ignored by setting show-colors? False
   infect
  ]
  tick
end



to time-runs ; makes the clock tick
  set Minute Minute + 1
  if Minute = 60 [set Minute 0 set Hour Hour + 1]
  if Hour = 6 [set day? true ]
  if (Hour = 23) and (Minute = 30) [set day? False]
  if Hour = 24 [set Hour 0 set Day (Day + 1)]
end

;to-report a-walker
;let counthousehold length household
;if (mobility = "free") or (mobility = "isolation") [
;    ifelse (length household + length sick-household) = 0 [report 0]
;    [ ifelse random (counthousehold + length sick-household) < counthousehold
;;    [ ifelse random (length household + length sick-household) < length household
;      [report 1] [report 5] ]]
;if mobility = "quarantined" [
;    ifelse (counthousehold + (count tents-here with [((infection-perception = "healthy") or (compliant? = False)) and (destination = "none")])) = 0 [report 0]
;    [ ifelse random (counthousehold + count tents-here with [((infection-perception = "healthy") or (compliant? = False)) and (destination = "none")]) < counthousehold
;      [ report 1][report 4] ]]
;
;if mobility = "no-elderly" [
;;  ifelse (counthousehold + length sick-household) = 0 [report 0]  ;; 1!
;   let e-household filter [ s -> s != "elderly" ] household
;   let e-sick-household filter [ s -> s != "elderly" ] sick-household
;   let e-counthousehold length e-household
;    ifelse ((e-counthousehold + length e-sick-household) = 0) [report 0]
;    [ ifelse random (e-counthousehold + length e-sick-household) < e-counthousehold
;;    ifelse ((length e-household + length e-sick-household) = 0) [ report 0]
;;    [ ifelse random (length e-household + length e-sick-household) < length e-household
;      [report 2] [report 3]
;  ]]
;end


to-report a-walker  ;; ISOchange
let counthousehold length household
if (mobility = "free") [;; ISOchange or (mobility = "isolation") [
    ifelse (length household + length sick-household) = 0 [report 0]
    [ ifelse random (counthousehold + length sick-household) < counthousehold
;    [ ifelse random (length household + length sick-household) < length household
      [report 1] [report 5] ]]

if mobility = "isolation" [
    ifelse any? tents with [(myhome = [myhome] of myself) and (infection = "symptomatic")]   ;; hier kan alleen 'true' op geantwoord worden als deze persoon niet-compliant is.
    ;; if there is a noncompliant person:
    [ ;show (word "there's non-compliant people in my household" self)
      let noncompliant (count tents-here with [(compliant? = false) and (destination = "none")])  ;; ISOchange2 (added destination = "none")
      ifelse noncompliant = 0 [report 0]  ;; if there is no noncompliant person at home, 0 is reported:
      ;; if the noncompliant person is at home, it depends on the destination (latrine/water) what the chance is that 6 is reported:
      [ifelse Minute = latrine-time [
        ifelse random-float 1 < (noncompliant / household-size) [report 6] [report 0]] ;; hier mag geen stop commando
        ;; if the command is go-to-waterpoint:
        [report 6]]]
    ;; if there is no symptomatic person, the same happens as if mobility = free
    [ifelse (length household + length sick-household) = 0 [report 0]
    [ ifelse random (counthousehold + length sick-household) < counthousehold
;    [ ifelse random (length household + length sick-household) < length household
        [report 1] [report 5] ]]]

if mobility = "quarantined" [
    ifelse (counthousehold + (count tents-here with [((infection-perception = "healthy") or (compliant? = False)) and (destination = "none")])) = 0 [report 0]
    [ ifelse random (counthousehold + count tents-here with [((infection-perception = "healthy") or (compliant? = False)) and (destination = "none")]) < counthousehold
      [ report 1][report 4] ]]

if mobility = "no-elderly" [
;  ifelse (counthousehold + length sick-household) = 0 [report 0]  ;; 1!
   let e-household filter [ s -> s != "elderly" ] household
   let e-sick-household filter [ s -> s != "elderly" ] sick-household
   let e-counthousehold length e-household
    ifelse ((e-counthousehold + length e-sick-household) = 0) [report 0]
    [ ifelse random (e-counthousehold + length e-sick-household) < e-counthousehold
;    ifelse ((length e-household + length e-sick-household) = 0) [ report 0]
;    [ ifelse random (length e-household + length e-sick-household) < length e-household
      [report 2] [report 3]
  ]]
end


to-report a-food-walker
  let c-household filter [ s -> s != "child" ] household   ; c-household is the household without children
  let c-sick-household filter [ s -> s != "child" ] sick-household  ; c-sick-household is the sick-household without children
  let c-counthousehold length c-household

if (mobility = "free")[ ; or (mobility = "isolation") [
    ifelse (c-counthousehold + length c-sick-household) = 0 [report 0]   ; if there is no-one at home: report 0
    [ ifelse random (c-counthousehold + length c-sick-household) < c-counthousehold  ; if a healthy person is chosen: report 1
      [report 1] [report 5] ]]                                                       ; if a sick person is chosen: report 5

if mobility = "isolation" [ ;; ISOchange
    ifelse any? tents with [(myhome = [myhome] of myself) and (infection = "symptomatic")]   ;; hier kan alleen 'true' op geantwoord worden als deze persoon niet-compliant is.
    ;; if there is a noncompliant person:
    [ let noncompliant (count tents-here with [(compliant? = false) and (my-age != "child")])
      ifelse noncompliant = 0 [report 0]  ;; if there is no noncompliant person at home, 0 is reported:
        [report 6]]
    ;; if there is no symptomatic person, the same happens as if mobility = free
    [ ifelse (c-counthousehold + length c-sick-household) = 0 [report 0]
      [ ifelse random (c-counthousehold + length c-sick-household) < c-counthousehold
        [report 1] [report 5] ]]]

if mobility = "quarantined" [
;    let healthy-nochild tents-here with [(my-age != "child") and ((infection-perception = "healthy") or (compliant? = False)) and (destination = "none")]  !
;    ifelse (c-counthousehold + (count healthy-nochild)) = 0 [report 0]
    ifelse (c-counthousehold + (count tents-here with [(my-age != "child") and ((infection-perception = "healthy") or (compliant? = False)) and (destination = "none")])) = 0 [report 0]
    [ ifelse random (c-counthousehold + count tents-here with [(my-age != "child") and ((infection-perception = "healthy") or (compliant? = False)) and (destination = "none")]) < c-counthousehold
;      healthy-nochild ) < c-counthousehold
      [ report 1][report 4] ]]

if mobility = "no-elderly" [
;  ifelse (c-counthousehold + length c-sick-household) = 0 [report 0]   ;;  1!
   let e-household filter [ s -> s != "elderly" ] c-household
   let e-sick-household filter [ s -> s != "elderly" ] c-sick-household

    ifelse ((length e-household + length e-sick-household) = 0) [report 0]
    [ ifelse random (length e-household + length e-sick-household) < length e-household
      [report 2] [ report 3] ; show (word who "e-household:" e-household "e-sick-household:" e-sick-household)
  ]]
end


to go-get-food2
  let free-tents tents-here with [destination = "none"]
  let the-walker a-food-walker
  let c-household filter [ s -> s != "child" ] household
  let c-sick-household filter [ s -> s != "child" ] sick-household

  ifelse the-walker != 0
   [ ifelse the-walker = 1 [  ;; a random healthy person
      let person item (random (length c-household)) c-household   ; gives 'adult' or 'elderly'
      let new-walker position person household
      hatch 1 [
        set walker? true
        set color brown
        set my-age item new-walker household
        set occupancy "busy"
        set destination (one-of foodpoints)
        ifelse random 100 < compliance [set compliant? true ][set compliant? false] ]
      set household remove-item new-walker household ]
   [ ifelse the-walker = 2 [  ;; a non-elderly from the healthy people
      let e-household filter [ s -> s != "elderly" ] c-household
        let person item (random (length e-household)) e-household   ; gives 'adult'
        let new-walker position person household    ; because it is about healthy people, it doesn't matter which one specifically is going.
      hatch 1 [
        set walker? true
        set color brown
        set my-age item new-walker household
        set occupancy "busy"
        set destination (one-of foodpoints)
          ifelse random 100 < compliance [set compliant? true ][set compliant? false] ]
      set household remove-item new-walker household ]
        [ ifelse the-walker = 3 [;show (word "food" who)   ;; a non-elderly from the sick people
          let designated-walker one-of free-tents with [my-age = "adult"]
      ask designated-walker [   ;; hier zat de ASK error. Opgelost? 13/08
        set walker? true
        set occupancy "busy"
        set destination (one-of foodpoints) ]
      let to-remove position [my-age] of designated-walker sick-household
        set sick-household remove-item to-remove sick-household]
   [ ifelse the-walker = 4 [  ;; a tent with [(destination = "none") and ((infection-perception = "healthy") or (compliant? = False))]
      let designated-walker one-of free-tents with [(my-age != "child") and ((infection-perception = "healthy") or (compliant? = False))]
      ask designated-walker [
        set walker? true
        set occupancy "busy"
        set destination (one-of foodpoints) ]
      let to-remove position [my-age] of designated-walker sick-household
        set sick-household remove-item to-remove sick-household]
   [ ifelse the-walker = 5 [  ;; a random sick-tent
        let designated-walker one-of free-tents with [my-age != "child"]
      ask designated-walker [    ;; HIER ZIT EEN ASK ERROR (opgelost?)
        set walker? true
        set occupancy "busy"
        set destination (one-of foodpoints) ]
      let to-remove position [my-age] of designated-walker sick-household
        set sick-household remove-item to-remove sick-household]
   [if the-walker = 6 [
     let designated-walker one-of free-tents with [(compliant? = False) and (my-age != "child")]
     ask designated-walker [
        set walker? true
        set occupancy "busy"
        set destination (one-of foodpoints) ]
      let to-remove position [my-age] of designated-walker sick-household
        set sick-household remove-item to-remove sick-household]]

  ]]]]]
  ;; if the-walker reports 0, there is no one at home to walk, so the timer is reset:
  [set food-time (food-time + 1)
    if food-time > 20 [set food-time 6]]   ;; klopt dit? of moet dit opgelost worden dat ze het niet ineens overslaan als het nacht wordt?
end


to go-to-latrines2  ; create a walker and head for nearest latrine
  if ((length household + length sick-household) != 0) [
    let best-latrines min-n-of 2 latrines [distance myself]
    let best-latrine min-one-of latrines [length waiting-list]
  let the-walker a-walker
;  ifelse the-walker != 0  ;because the command starts with an if .. != 0 [, this should be redundant.
    ifelse the-walker = 1 [  ;; a random healthy person
      let new-walker random (length household)
      hatch 1 [
        set walker? true
        set color brown
        set my-age item new-walker household
        set occupancy "busy"
        set destination best-latrine
        ifelse random 100 < compliance [set compliant? true ][set compliant? false] ]
      set household remove-item new-walker household ]
   [ ifelse the-walker = 2 [  ;; a non-elderly from the healthy people
      let e-household filter [ s -> s != "elderly" ] household
        let person item (random (length e-household)) e-household   ; gives 'adult' or 'child'
        let new-walker position person household    ; gives a number - because it is about healthy people, it doesn't matter which one specifically is going.
      hatch 1 [
        set walker? true
        set color brown
        set my-age item new-walker household
        set occupancy "busy"
        set destination best-latrine
        ifelse random 100 < compliance [set compliant? true ][set compliant? false] ] ; compliance is measured on a scale [1-100]
      set household remove-item new-walker household ]
   [ ifelse the-walker = 3 [ ;; a non-elderly from the sick people
      let designated-walker one-of tents-here with [(destination = "none") and (my-age != "elderly")]
        ask designated-walker [  ;; hier zit een ASK error bij no-elderly.
        set walker? true
        set occupancy "busy"
        set destination best-latrine ]
      let to-remove position [my-age] of designated-walker sick-household
      set sick-household remove-item to-remove sick-household]
   [ ifelse the-walker = 4 [  ;; a tent with [(destination = "none") and ((infection-perception = "healthy") or (compliant? = False))]
      let designated-walker one-of tents-here with [(destination = "none") and ((infection-perception = "healthy") or (compliant? = False))]
      ask designated-walker [
        set walker? true
        set occupancy "busy"
        set destination best-latrine ]
      let to-remove position [my-age] of designated-walker sick-household
        set sick-household remove-item to-remove sick-household]
   [ ifelse the-walker = 5 [  ;; a random sick-tent
      let designated-walker one-of tents-here with [destination = "none"]
      ask designated-walker [
        set walker? true
        set occupancy "busy"
        set destination best-latrine ]
      let to-remove position [my-age] of designated-walker sick-household
        set sick-household remove-item to-remove sick-household]
   [if the-walker = 6 [
     let designated-walker one-of tents-here with [(destination = "none") and (compliant? = False)]
     ask designated-walker [
        set walker? true
        set occupancy "busy"
        set destination best-latrine ]
      let to-remove position [my-age] of designated-walker sick-household
        set sick-household remove-item to-remove sick-household]
  ]]]]]]
end


to go-to-waterpoint2   ; create a walker and head for nearest waterpoint
  let free-tents tents-here with [destination = "none"]
  ifelse ((length household + length sick-household) != 0) [
    let best-waterpoints min-n-of 2 waterpoints [distance myself]
    let best-waterpoint min-one-of waterpoints [length waiting-list]
    let the-walker a-walker
   ifelse the-walker = 1 [  ;; a random healthy person
      let new-walker random (length household)
      hatch 1 [
        set walker? true
        set color brown
        set my-age item new-walker household
        set occupancy "busy"
        set destination best-waterpoint
        ifelse random 100 < compliance [set compliant? true ][set compliant? false] ]
      set household remove-item new-walker household ]
   [ ifelse the-walker = 2 [  ;; a non-elderly from the healthy people
      let e-household filter [ s -> s != "elderly" ] household
        let person item (random (length e-household)) e-household   ; gives 'adult' or 'child'
        let new-walker position person household    ; because it is about healthy people, it doesn't matter which one specifically is going.
      hatch 1 [
        set walker? true
        set color brown
        set my-age item new-walker household
        set occupancy "busy"
        set destination best-waterpoint
        ifelse random 100 < compliance [set compliant? true ][set compliant? false] ]
      set household remove-item new-walker household   ]
   [ ifelse the-walker = 3 [  ;; a non-elderly from the sick people
        let designated-walker one-of free-tents with [(my-age != "elderly")]
      ask designated-walker [
        set walker? true
        set occupancy "busy"
        set destination best-waterpoint ]
      let to-remove position [my-age] of designated-walker sick-household
      set sick-household remove-item to-remove sick-household]
   [ ifelse the-walker = 4 [  ;; a
      let designated-walker one-of tents-here with [(destination = "none") and ((infection-perception = "healthy") or (compliant? = False))];; free-tents with [((infection-perception = "healthy") or (compliant? = False))]
      ask designated-walker [
        set walker? true
        set occupancy "busy"
        set destination best-waterpoint ]
      let to-remove position [my-age] of designated-walker sick-household
        set sick-household remove-item to-remove sick-household]
   [ ifelse the-walker = 5 [  ;; a random sick-tent
      let designated-walker one-of free-tents
      ask designated-walker [
        set walker? true
        set occupancy "busy"
        set destination best-waterpoint ]
      let to-remove position [my-age] of designated-walker sick-household
        set sick-household remove-item to-remove sick-household]
   [if the-walker = 6 [
     let designated-walker one-of tents-here with [(destination = "none") and (compliant? = False)]
     ask designated-walker [ ;;;; hier zit een error!
        set walker? true
        set occupancy "busy"
        set destination best-waterpoint ]
      let to-remove position [my-age] of designated-walker sick-household
        set sick-household remove-item to-remove sick-household]
  ]]]]]]
;  if there's no-one at home now, set water-time + 1.
    [set water-time (water-time + 1)]
end


to go-to-healthcare  ; Currently, healthcare-time is specified for normal healthcare usage. Not for COVID-19 care.
  let free-tents tents-here with [destination = "none"]
    let counthousehold length household

  ;;ISOchange
  if mobility = "isolation" [
    if any? tents with [(myhome = [myhome] of myself) and (infection = "symptomatic")]
    [ let noncompliant count free-tents with [(infection-perception = "healthy") and (compliant? = False)]
      if noncompliant != 0 [
        let designated-walker one-of free-tents with [(infection-perception = "healthy") and (compliant? = False)]
        ask designated-walker [
          set walker? true
          set occupancy "busy"
          set destination (min-one-of hc-facs [distance myself]) ]
        let to-remove position [my-age] of designated-walker sick-household
          set sick-household remove-item to-remove sick-household]
     stop] ]  ; if this part is exectued, the following should not be executed.

    ;; if there is no symptomatic person in the household, while mobility = isolation, or if mobility != isolation:
  if (counthousehold + (count free-tents with [infection-perception = "healthy"])) > 0
   [ ifelse random (counthousehold + count tents-here with [(destination = "none") and (infection-perception = "healthy")]) < counthousehold
      [ let new-walker random (counthousehold)
        hatch 1 [
          set walker? true
          set occupancy "busy"
          set my-age item new-walker household
          set destination (min-one-of hc-facs [distance myself])
          ifelse random 100 < compliance [set compliant? true ][set compliant? false] ]
        set household remove-item new-walker household ]
      [let designated-walker one-of free-tents with [infection-perception = "healthy"]
        ask designated-walker [
          set walker? true
          set occupancy "busy"
          set destination (min-one-of hc-facs [distance myself]) ]
        let to-remove position [my-age] of designated-walker sick-household
          set sick-household remove-item to-remove sick-household] ]
end


to new-walking
  ask tents with [walker? = True] [

    ;;; if you want to ENABLE WALKING, the next 2 rows should be un-commented:
;    ifelse distance destination > speed [new-lookout-and-walk]
;    [
    ;; if distance < speed:
    ;; if destination = myhome, no need to queue, so just go home:
    ;; but if destination != myhome, tents follow the last tent in the queue (if there is a queue). If there is no queue, they move to the patch, (round?)
    ;; COVID-facilities don't have a queue, so ask for bed-capacity.

    if destination = myhome [ move-to myhome
      set destination "none"
      set occupancy "free"
      ifelse infected? = True [
        ifelse (infection = "severely-symptomatic") or (infection = "critical") [set destination min-one-of COVID-facilities [distance myself]

        ]
        [ ask shelters in-radius 0 [set sick-household lput ([my-age] of myself) sick-household]

            set walker? false] stop]
        [ ask shelters in-radius 0 [set household lput ([my-age] of myself) household]
          die] stop]

    ifelse destination = one-of COVID-facilities [
      ifelse [bed-capacity] of destination < 1 [ ; there is no room in-hospital right now
      ]

        ;; wait for room in hospital.

;; OLD: for walking
;        face destination
;        ifelse distance destination > patch-length [
;          fd (floor distance destination) ]
;        [ if not any? other tents in-cone (1.5 / patch-length) 90 [fd (queue-distance / patch-length)]]]

      ; when bed-capacity is sufficient:
        [ if occupancy = "free" [ move-to destination
          set occupancy "in-hospital"
        set walker? False
          if infection = "critical" [demand-IC-capacity]
           ; Not specified yet what happens if no bed-capacity is available.
          if infection = "severely-symptomatic" [demand-bed-capacity]]
          ; in 'to become-recovered', the person releases the capacity and sets its new destination (home) when recovered
    ]]

    ;; if destination is any other facility:
      ;; Twee mogelijkheden:
      ;; 1) net als bij een COVID-facility: ifelse distance destination > patch-length [ jump or move 0.5m/1m ]
      ;; 2) altijd netjes aansluiten. NU GEÏMPLEMENTEERD.
      [ ifelse queue-time = 0 [ ;; when stepping into a queue
        ifelse [length waiting-list] of destination > 0 [
          let p [last waiting-list] of destination
          face p fd (distance p - (queue-distance / patch-length))

          set queue-time (queue-time + 1)
          if queue-time = 1 [ask destination [set waiting-list lput myself waiting-list] ]]
        ;; if waiting-list is empty:
        [ move-to destination
          set queue-time (queue-time + 1)
          if queue-time = 1 [ask destination [set waiting-list lput myself waiting-list] ]] ]

        ;; if queue-time was not 0: (already in queue) ;; THIS IS WHERE A NEW LOGIC IS NEEDED.
        [if patch-here != [patch-here] of destination [
          face destination
          ifelse not any? other tents in-cone (queue-distance / patch-length) 90 [fd (queue-distance / patch-length)]
        [if any? other tents in-cone (queue-distance / patch-length) 90 with [destination = "Home"] [rt 45 fd (queue-distance / patch-length)]]]
        ]]]
;   ]
end


to new-lookout-and-walk
  face destination
  fd speed
  if any? shelters in-radius (queue-distance / patch-length)
   [rt -135
      while [any? shelters in-radius (queue-distance / patch-length)] [fd (queue-distance / patch-length)] ]
end


to manage-queues
  ask facilities [
    if length waiting-list >= 1 [
    ; if there is a waiting list:
      set serving-time (serving-time - 1)
      if serving-time = 0 [ask item 0 waiting-list [ set destination [myhome] of self set queue-time 0 ]
      set waiting-list but-first waiting-list
        set serving-time initial-serving-time
        ; also bring the next customer:
        if length waiting-list >= 1 [
          while [item 0 waiting-list = nobody][ ;print who print waiting-list
          set waiting-list but-first waiting-list  ;print waiting-list
;          ]
          ask item 0 waiting-list [move-to myself ;set queue-time 0
        ]]
  ]]]]
end





;;;;;;;;;;;;;;; VIRUS SPREAD ;;;;;;;;;;;;;;

to initiate-corona
  ask one-of tents [
    let age-of-sick-agent random (length household)
    set sick-household lput item age-of-sick-agent household sick-household
    set household remove-item age-of-sick-agent household
    hatch 1 [
      set my-age item 0 sick-household
      set infected? True
      set infection "infected"
      set next-stage "pre-symptomatic"
      set time-until-next-stage 3 * 24
      set destination "none"
      ifelse random 100 < compliance [set compliant? true ][set compliant? false] ]
    show-infections  ]

  set infection-locations [] ;; to enable listing all infection locations during simulation
end

to show-infections    ; colors turtles according to their health status:
  if show-colors? = True [
  ask tents with [infection = "infected"] [set color cyan]
  ask tents with [infection = "pre-symptomatic"] [set color yellow]
  ask tents with [infection = "asymptomatic"] [set color yellow]
  ask tents with [infection = "symptomatic"] [set color orange]
  ask tents with [infection = "severely-symptomatic"] [set color red]
  ask tents with [infection = "critical"] [set color magenta]
  ask tents with [infection = "recovered"] [set color grey]
  ]
  ;; tents that are within 1,5m(infection-distance) of an infectious tent can become infected. This risk is indicated with a green color.
  ask tents with [infected? = False]
  [ let infecting-agents (tents with [(infected? = True) and (infection = "pre-symptomatic") or (infection = "symptomatic") or (infection = "asymptomatic")] in-radius infection-distance)
    ifelse any? infecting-agents
    ; yes, there are infecting agents:
    [set color green set time-until-next-stage time-until-next-stage + 1
      let infecting-agent one-of infecting-agents
    ;; set destination-when-infected (list [who] of one-of tents with [(infected? = True) and (infection = "pre-symptomatic") or (infection = "symptomatic") or (infection = "asymptomatic")] in-radius infection-distance destination queue-time) ]
      ifelse destination = myhome [set destination-when-infected (list who my-age infecting-agent ([infection] of infecting-agent) ([my-age] of infecting-agent) (min-one-of facilities [distance myself]) queue-time)]
      [set destination-when-infected (list who my-age infecting-agent ([infection] of infecting-agent) ([my-age] of infecting-agent) destination queue-time) ]]
    ; if there are no infecting-agents:
    [set time-until-next-stage 0
     ifelse walker? [set color brown][set color blue]]]

end


to infect   ; is currently initiated every tick.
  ask tents with [color = green] [
    ;; if a sick person passed by a shelters and infects the shelter:
    ifelse destination = "Home" [
      foreach household [[instance]  -> if (random-float 1 < (transmission-probability * time-until-next-stage)) and (instance != "child") [  ; deze regel zou nog dubieus kunnen zijn.
        ask shelters in-radius 0 [
          set household remove-item (position instance household) household
          set sick-household lput instance sick-household
          hatch 1 [
            set my-age instance
            set destination "none"
            ifelse random 100 < compliance [set compliant? true ][set compliant? false] ]
        ] ]]]
    [ ifelse time-until-next-stage < 15    ; below 15 minutes of contact with an infected person, there's still a chance of no infection.
      [ let chance random-float 1
        ifelse my-age = "child" [if chance < (0.005 * transmission-probability * time-until-next-stage) [ become-infected ]] ; children have a lower chance to get infected.
        [ if chance < (0.01 * transmission-probability * time-until-next-stage) [ become-infected ]]]
      [ become-infected ]                  ; if more than 15 minutes around an infected person: become infected.
  ]]
end


to disease-progression
  set time-until-next-stage (time-until-next-stage - 1)
  if time-until-next-stage =  0
  [ ifelse next-stage = "pre-symptomatic" [ become-pre-symptomatic stop ]
    [ ifelse next-stage = "symptomatic" [ become-symptomatic stop ]
      [ ifelse next-stage = "asymptomatic" [ become-asymptomatic stop ]
        [ ifelse next-stage = "recovered" [ become-recovered ]
          [ ifelse next-stage = "severely-symptomatic" [ become-severely-symptomatic stop ]
            [ ifelse next-stage = "critical" [ become-critical stop ]
              [ if next-stage = "dead" [ become-dead ]
  ]]]]]]]
end

to become-infected
  set infected? True
  set infection "infected"
  set cum-infected cum-infected + 1
  let x random 10
  if x = 0 [set infection-perception "infected"]
  set next-stage "pre-symptomatic"
;  set time-until-next-stage 3
  set time-until-next-stage incubation-time
;  set destination-when-infected lput destination lput queue-time destination-when-infected
  set infection-locations lput destination-when-infected infection-locations
end

to-report incubation-time
  let sigma 2.1
  let mu 5.5

  let incubationperiod (exp random-normal ln(mu) ln(sqrt(sigma)))
  let pre-symptomatic-infectious-time ((random 24) + 24) ;; 1-2 days before symptom onset, people become infectious
  report round ((incubationperiod * 24) - pre-symptomatic-infectious-time)
end

;to-report incubation-time2
;  let sigma 2.1
;  let mu 5.5
;  report random-normal mu sqrt(sigma)
;end
;
;to test
;  show incubation-time
;end
;
;to test2
;  show incubation-time2
;end


to become-pre-symptomatic
  set infection "pre-symptomatic"
  let chance1 random-float 1
  let chance (chance1 / factor-asymptomatic)
  ifelse ((chance < 0.617) and (my-age = "elderly")) or ((chance < 0.48) and (my-age = "adult")) or ((chance < 0.556) and (my-age = "child"))
    [ set next-stage "symptomatic" ]
    [ set next-stage "asymptomatic" ]
  set time-until-next-stage (random 24 + 24) ;; between 1 and 2 days
end

to become-symptomatic
  set infection "symptomatic"
  set infection-perception "infected"
  set cum-infected cum-infected + 1
  let chance random-float 1

  ifelse ((chance < 0.063) and (my-age = "child")) or ((chance < 0.096) and (my-age = "adult")) or ((chance < 0.281) and (my-age = "elderly"))
  [ if ((chance < 0.033) and (my-age = "elderly")) [become-dead]
    set next-stage "severely-symptomatic"
    set time-until-next-stage symptomatic-to-hospital-time]
  [ set next-stage "recovered"
    set time-until-next-stage 7 * 24]

  if mobility = "isolation"[  ; as soon as there is 1 symptomatic person in a house, no one can go out anymore, unless one of them is non-compliant.
    if compliant? = True [ ;; ISOchange
      if not any? tents with [(myhome = [myhome] of myself) and (compliant? = False)]
      [ ask myhome [ask shelters in-radius 0 [set shelters shelters with [self != myself]]]]]]
end

to-report symptomatic-to-hospital-time
  let alpha ( 3.3 * 3.3 / 17.64)
  let lambda ( 1 / (17.64 / 3.3))
  report round ( (random-gamma alpha lambda) * 24)
end

;to test
;  show symptomatic-to-hospital-time
;end


to become-asymptomatic
  set infection "asymptomatic"
  set infection-perception "healthy"
  set cum-asymptomatic cum-asymptomatic + 1
  set next-stage "recovered"
  set time-until-next-stage 4 * 24
end

to become-severely-symptomatic
;  show (word who "becoming severely sick at " destination)
  set infection "severely-symptomatic"
  set cum-severe cum-severe + 1
  let chance random-float 1

  ifelse ((chance < 0.043) and (my-age = "child")) or ((chance < 0.152) and (my-age = "adult")) or ((chance < 0.275) and (my-age = "elderly"))
  [ if ((chance < 0.022) and (my-age = "adult")) or ((chance < 0.145) and (my-age = "elderly")) [
    set next-stage "dead"
    set time-until-next-stage severe-to-dead-time ]
    set next-stage "critical"
    set time-until-next-stage 2 * 24]
  [ set next-stage "recovered"
    set time-until-next-stage ((14 * 24) - symptomatic-to-hospital-time)]
  ; when at home, go to hospital when situation becomes severe:
  if destination = "none" [
    set walker? true
    let leaving self
    ask shelters in-radius 0 [
      let to-remove position [my-age] of leaving sick-household
      set sick-household remove-item to-remove sick-household]
    set destination min-one-of COVID-facilities [distance myself]
  if mobility = "isolation" [
    ask myhome [if count tents-here with [(infection = "symptomatic") and (compliant? = True)] = 0 [ask shelters in-radius 0
      [set shelters (turtle-set shelters self)]]]]
   ]
end


;to-report random-weibull [#scale #shape] ; goes scale then shape ;;; can't make this work properly.
;  let xWei random-float 1
;  let yWei (1 / #scale)
;  let zWei (#shape * (-1 * ln(1 - xWei))) ^ yWei
;  report zwei
;end


to-report severe-to-dead-time ;[#scale #shape]
  let time-in-days random-normal 8.8 1.8
  let time-in-hours time-in-days * 24
  report round (time-in-hours)
end


to become-critical
;  show (word who "becoming critically sick at " destination)
  set infection "critical"
  set cum-critical cum-critical + 1
  let chance random-float 1

  ifelse ((chance < 0.0006) and (my-age = "child")) or ((chance < 0.153) and (my-age = "adult")) or ((chance < 0.394) and (my-age = "elderly"))
  [ set next-stage "dead"
    set time-until-next-stage critical-to-dead-time]
  [ set next-stage "recovered"
    set time-until-next-stage critical-to-recovered-time]
  ; when at home, go to hospital when situation becomes critical:
  if destination = "none" [
    set walker? true
    let leaving self
    ask shelters in-radius 0 [
      let to-remove position [my-age] of leaving sick-household
      set sick-household remove-item to-remove sick-household]
    set destination min-one-of COVID-facilities [distance myself]]
  if destination = one-of COVID-facilities [demand-IC-capacity]
end

to-report critical-to-recovered-time  ;; random triangular distribution
  let FC ((7 - 5) / (12 - 5))
  let U random-float 1
  ifelse U < FC [
    report (5 + (sqrt (U * (12 - 5) * (7 - 5)))) * 24 ]
  [report round (12 - (sqrt ((1 - U ) * (12 - 5) * (12 - 7)))) * 24]
end

to-report critical-to-dead-time
  let time-in-days random-normal 7.5 3
  let time-in-hours time-in-days * 24
  report round (time-in-hours)
end


to become-recovered
  release-capacity
  set infection "recovered"
  set cum-recovered cum-recovered + 1
  set infection-perception "immune"
  set time-until-next-stage 1000 * 24;; 1000 days, not necessary?
  if patch-here != myhome [
    set destination myhome
    set walker? True
    set occupancy "free"]

  if mobility = "isolation" [
    ask myhome [if count tents-here with [(infection = "symptomatic") and (compliant? = True)] = 0 [ask shelters in-radius 0
      [set shelters (turtle-set shelters self)]]]]
end

to become-dead
  let dying self
  ifelse patch-here = myhome [
    ask shelters in-radius 0 [
      let to-remove position [my-age] of dying sick-household
      set sick-household remove-item to-remove sick-household
;      show sick-household
    ]] [release-capacity]
  set cum-dead cum-dead + 1
  set numtents numtents - 1
  if mobility = "isolation" [
    ask myhome [if count tents-here with [(infection = "symptomatic") and (compliant? = True)] = 0 [ask shelters in-radius 0
      [set shelters (turtle-set shelters self)]]]]
  die
end

to demand-IC-capacity
  ask destination [ ifelse IC-capacity > 0  ; change from hospital bed to IC bed]
    [set IC-capacity IC-capacity - 1    set in-IC in-IC + 1
     set bed-capacity bed-capacity + 1  set in-treatment in-treatment - 1 ]
    [if bed-capacity > 0 [
      set bed-capacity (bed-capacity - 1 ) set in-treatment (in-treatment + 1) ]]]
end

to demand-bed-capacity
  ask destination [if bed-capacity > 0 [
    set bed-capacity (bed-capacity - 1 ) set in-treatment (in-treatment + 1) ]]
end

to release-capacity
  if destination = one-of COVID-facilities [
    if infection = "critical" [ask destination [ set IC-capacity (IC-capacity + 1)  set in-IC (in-IC - 1)]]
    if infection = "severely-symptomatic" [ask destination [ set bed-capacity (bed-capacity + 1)  set in-treatment (in-treatment - 1)]]
  ]
  if patch-here != myhome [
    set destination myhome
    set walker? True
    set occupancy "free"]
end
@#$#@#$#@
GRAPHICS-WINDOW
211
11
531
632
-1
-1
12.0
1
10
1
1
1
0
0
0
1
0
25
0
50
0
0
1
ticks
30.0

BUTTON
43
77
106
110
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
70
345
120
390
Hour
Hour
0
1
11

BUTTON
108
109
171
142
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
31
109
106
142
go once
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

CHOOSER
12
437
150
482
mobility
mobility
"free" "quarantined" "isolation" "tracing-based" "no-elderly"
0

BUTTON
108
77
182
110
NIL
clear-all
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
36
393
146
438
number of people
numtents
17
1
11

MONITOR
23
345
73
390
NIL
Day
17
1
11

MONITOR
118
345
168
390
NIL
Minute
17
1
11

BUTTON
19
10
102
43
NIL
initiate-corona
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
43
301
100
346
NIL
day?
17
1
11

SWITCH
17
268
189
301
poor-conditions?
poor-conditions?
0
1
-1000

CHOOSER
12
176
150
221
plotsize-shelters
plotsize-shelters
"12,5 m2" "25 m2" "50 m2" "100 m2"
0

CHOOSER
12
220
104
265
block-size
block-size
"60 shelters" "120 shelters" "test-mode: few shelters"
1

CHOOSER
104
220
196
265
household-size
household-size
5 7
0

PLOT
564
115
875
284
Infected agents
time
NIL
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Infected" 1.0 0 -11221820 true "" "plot count tents with [(infected? = True)]\n\nif ticks > 1440 ; 1440 ticks equals 1 day\n[\n  ; scroll the range of the plot so\n  ; only the last 200 ticks are visible\n  set-plot-x-range (ticks - 800) ticks                                       \n]"
"Symptomatic" 1.0 0 -955883 true "" "plot count tents with [(infection = \"symptomatic\")]"
"Pre-symptomatic" 1.0 0 -1184463 true "" "plot count tents with [(infection = \"pre-symptomatic\")]"
"Severely-symptomatic" 1.0 0 -2674135 true "" "plot count tents with [(infection = \"severely-symptomatic\")]"
"Critical" 1.0 0 -8630108 true "" "plot count tents with [(infection = \"critical\")]"
"Recovered" 1.0 0 -7500403 true "" "plot count tents with [(infection = \"immune\")]"
"Asymptomatic" 1.0 0 -987046 true "" "plot count tents with [(infection = \"asymptomatic\")]"

PLOT
564
287
875
437
Infected agents (cumulative)
time
NIL
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"total infected" 24.0 0 -11221820 true "" ";plot cum-infected"
"total asymptomatic" 1.0 0 -987046 true "" "plot cum-asymptomatic"
"total symptomatic" 1.0 0 -955883 true "" "plot cum-symptomatic"
"total severely sick" 1.0 0 -2674135 true "" "plot cum-severe"
"total critically sick" 1.0 0 -8630108 true "" "plot cum-critical"
"total dead" 1.0 0 -16777216 true "" "plot cum-dead"
"total recovered" 1.0 0 -7500403 true "" "plot cum-recovered"

BUTTON
19
43
197
76
Create COVID-19 treatment facility
create-COVID-facility
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

PLOT
564
450
874
600
Patients in COVID-facility
NIL
NIL
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"in treatment" 1.0 0 -2064490 true "" "plot [in-treatment] of one-of COVID-facilities"
"in IC" 1.0 0 -5825686 true "" "plot [in-IC] of one-of COVID-facilities"

SLIDER
14
538
152
571
compliance
compliance
0
100
100.0
1
1
NIL
HORIZONTAL

SLIDER
14
575
152
608
factor-asymptomatic
factor-asymptomatic
0.5
2
1.0
0.5
1
NIL
HORIZONTAL

TEXTBOX
7
613
219
683
When adapting the asymptomatic factor, the percentage of asymptomatic people gets adapted across all age groups.\n
11
0.0
1

SLIDER
11
143
207
176
transmission-probability
transmission-probability
0
100
5.0
1
1
%
HORIZONTAL

OUTPUT
563
20
803
74
11

CHOOSER
12
481
150
526
queue-distance
queue-distance
0.5 1 1.5
2

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bread
false
0
Polygon -16777216 true false 140 145 170 250 245 190 234 122 247 107 260 79 260 55 245 40 215 32 185 40 155 31 122 41 108 53 28 118 110 115 140 130
Polygon -7500403 true true 135 151 165 256 240 196 225 121 241 105 255 76 255 61 240 46 210 38 180 46 150 37 120 46 105 61 47 108 105 121 135 136
Polygon -1 true false 60 181 45 256 165 256 150 181 165 166 180 136 180 121 165 106 135 98 105 106 75 97 46 107 29 118 30 136 45 166 60 181
Polygon -16777216 false false 45 255 165 255 150 180 165 165 180 135 180 120 165 105 135 97 105 105 76 96 46 106 29 118 30 135 45 165 60 180
Line -16777216 false 165 255 239 195

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

campsite
false
0
Polygon -7500403 true true 150 11 30 221 270 221
Polygon -16777216 true false 151 90 92 221 212 221
Line -7500403 true 150 30 150 225

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

drop
false
0
Circle -7500403 true true 73 133 152
Polygon -7500403 true true 219 181 205 152 185 120 174 95 163 64 156 37 149 7 147 166
Polygon -7500403 true true 79 182 95 152 115 120 126 95 137 64 144 37 150 6 154 165

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

healthcare
false
8
Circle -1 true false -2 -2 304
Rectangle -2674135 true false 120 0 180 300
Rectangle -2674135 true false -30 120 300 180

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person doctor
false
0
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Polygon -13345367 true false 135 90 150 105 135 135 150 150 165 135 150 105 165 90
Polygon -7500403 true true 105 90 60 195 90 210 135 105
Polygon -7500403 true true 195 90 240 195 210 210 165 105
Circle -7500403 true true 110 5 80
Rectangle -7500403 true true 127 79 172 94
Polygon -1 true false 105 90 60 195 90 210 114 156 120 195 90 270 210 270 180 195 186 155 210 210 240 195 195 90 165 90 150 150 135 90
Line -16777216 false 150 148 150 270
Line -16777216 false 196 90 151 149
Line -16777216 false 104 90 149 149
Circle -1 true false 180 0 30
Line -16777216 false 180 15 120 15
Line -16777216 false 150 195 165 195
Line -16777216 false 150 240 165 240
Line -16777216 false 150 150 165 150

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -1 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -1 true false 90 90 120
Circle -7500403 true true 120 120 60

toilet
false
0
Circle -7500403 true true 75 45 30
Polygon -7500403 true true 75 75 75 135 60 195 60 225 75 225 90 165 105 225 120 225 120 195 105 135 105 75
Polygon -7500403 true true 105 75 135 120 135 135 90 90
Polygon -7500403 true true 75 75 45 120 45 135 90 90
Circle -7500403 true true 195 45 30
Polygon -7500403 true true 195 75 195 135 195 165 180 225 195 225 210 165 225 225 240 225 225 165 225 135 225 75
Polygon -7500403 true true 225 75 255 120 255 135 210 90
Polygon -7500403 true true 195 75 165 120 165 135 210 90
Polygon -7500403 true true 195 90 165 195 255 195 225 90
Rectangle -7500403 false true 15 30 285 240

toilet2
false
0
Rectangle -1 true false 0 0 345 300
Polygon -7500403 true true 255 60 300 165 285 165 255 105 255 180 285 300 255 300 225 195 195 300 180 300 165 300 195 180 195 105 165 165 150 165 195 60 255 60
Polygon -7500403 true true 45 60 0 165 15 165 45 105 45 180 15 300 45 300 75 195 105 300 120 300 135 300 105 180 105 105 135 165 150 165 105 60 45 60
Circle -7500403 true true 192 -4 67
Circle -7500403 true true 41 -4 67
Polygon -7500403 true true 195 105 165 240 285 240 255 105

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wc
false
0
Rectangle -7500403 false true 0 0 285 270
Line -7500403 true 15 45 60 255
Line -7500403 true 60 255 90 120
Line -7500403 true 90 120 120 255
Line -7500403 true 120 255 180 45
Line -7500403 true 270 255 240 255
Line -7500403 true 210 240 195 210
Line -7500403 true 195 210 180 165
Line -7500403 true 180 135 180 165
Line -7500403 true 240 255 210 240
Line -7500403 true 270 45 240 45
Line -7500403 true 240 45 210 60
Line -7500403 true 210 60 195 90
Line -7500403 true 195 90 180 135

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.1.1
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="Effect of mobility policies 100days (5x)" repetitions="5" runMetricsEveryStep="true">
    <setup>setup
initiate-corona
create-COVID-facility</setup>
    <go>go</go>
    <final>output-write infection-locations
output-write mobility
output-write timer
export-output "output-mobility"
export-output (word "output-mobility_" mobility "_timer_" timer)</final>
    <timeLimit steps="144000"/>
    <metric>Day</metric>
    <metric>Hour</metric>
    <metric>count tents</metric>
    <metric>count tents with [(my-age = "elderly") and (infected? = true)]</metric>
    <metric>count tents with [(my-age = "child") and (infected? = true)]</metric>
    <metric>count tents with [(my-age = "adult") and (infected? = true)]</metric>
    <metric>count tents with [(my-age = "elderly") and (infection = "symptomatic")]</metric>
    <metric>count tents with [(my-age = "child") and (infection = "symptomatic")]</metric>
    <metric>count tents with [(my-age = "adult") and (infection = "symptomatic")]</metric>
    <metric>count tents with [(my-age = "elderly") and (infection = "severely-symptomatic")]</metric>
    <metric>count tents with [(my-age = "child") and (infection = "severely-symptomatic")]</metric>
    <metric>count tents with [(my-age = "adult") and (infection = "severely-symptomatic")]</metric>
    <metric>count tents with [(my-age = "elderly") and (infection = "critical")]</metric>
    <metric>count tents with [(my-age = "child") and (infection = "critical")]</metric>
    <metric>count tents with [(my-age = "adult") and (infection = "critical")]</metric>
    <metric>count tents with [(my-age = "elderly") and (infection = "recovered")]</metric>
    <metric>count tents with [(my-age = "child") and (infection = "recovered")]</metric>
    <metric>count tents with [(my-age = "adult") and (infection = "recovered")]</metric>
    <metric>cum-dead</metric>
    <metric>cum-recovered</metric>
    <metric>[ic-capacity] of one-of covid-facilities</metric>
    <metric>[bed-capacity] of one-of covid-facilities</metric>
    <enumeratedValueSet variable="compliance">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="transmission-probability">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="household-size">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="plotsize-shelters">
      <value value="&quot;12,5 m2&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="factor-asymptomatic">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mobility">
      <value value="&quot;free&quot;"/>
      <value value="&quot;isolation&quot;"/>
      <value value="&quot;no-elderly&quot;"/>
      <value value="&quot;quarantined&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poor-conditions?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="block-size">
      <value value="&quot;120 shelters&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="queue-distance">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-colors?">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Run until 100% infected (m=quarantined)" repetitions="1" runMetricsEveryStep="true">
    <setup>setup
initiate-corona
create-COVID-facility</setup>
    <go>go</go>
    <final>output-write infection-locations
output-write timer
export-output (word "testrun-output_" mobility "_" timer)</final>
    <exitCondition>cum-infected = numtents</exitCondition>
    <metric>Day</metric>
    <metric>Hour</metric>
    <metric>count tents</metric>
    <metric>count tents with [(my-age = "elderly") and (infected? = true)]</metric>
    <metric>count tents with [(my-age = "child") and (infected? = true)]</metric>
    <metric>count tents with [(my-age = "adult") and (infected? = true)]</metric>
    <metric>count tents with [(my-age = "elderly") and (infection = "symptomatic")]</metric>
    <metric>count tents with [(my-age = "child") and (infection = "symptomatic")]</metric>
    <metric>count tents with [(my-age = "adult") and (infection = "symptomatic")]</metric>
    <metric>count tents with [(my-age = "elderly") and (infection = "severely-symptomatic")]</metric>
    <metric>count tents with [(my-age = "child") and (infection = "severely-symptomatic")]</metric>
    <metric>count tents with [(my-age = "adult") and (infection = "severely-symptomatic")]</metric>
    <metric>count tents with [(my-age = "elderly") and (infection = "critical")]</metric>
    <metric>count tents with [(my-age = "child") and (infection = "critical")]</metric>
    <metric>count tents with [(my-age = "adult") and (infection = "critical")]</metric>
    <metric>count tents with [(my-age = "elderly") and (infection = "recovered")]</metric>
    <metric>count tents with [(my-age = "child") and (infection = "recovered")]</metric>
    <metric>count tents with [(my-age = "adult") and (infection = "recovered")]</metric>
    <metric>cum-dead</metric>
    <metric>cum-recovered</metric>
    <metric>[ic-capacity] of one-of covid-facilities</metric>
    <metric>[bed-capacity] of one-of covid-facilities</metric>
    <enumeratedValueSet variable="compliance">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="transmission-probability">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="household-size">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="plotsize-shelters">
      <value value="&quot;12,5 m2&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="factor-asymptomatic">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mobility">
      <value value="&quot;quarantined&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poor-conditions?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="block-size">
      <value value="&quot;120 shelters&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="queue-distance">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-colors?">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Effect of 90%compliance free-mobility (5x)" repetitions="5" runMetricsEveryStep="true">
    <setup>setup
initiate-corona
create-COVID-facility</setup>
    <go>go</go>
    <final>output-write infection-locations
output-write mobility
output-write compliance
output-write timer
export-output "output-mobility-compliance"
export-output (word "output-mobility_" mobility"_compliance_" compliance "_timer_" timer)</final>
    <timeLimit steps="72000"/>
    <metric>Day</metric>
    <metric>Hour</metric>
    <metric>count tents</metric>
    <metric>count tents with [(my-age = "elderly") and (infected? = true)]</metric>
    <metric>count tents with [(my-age = "child") and (infected? = true)]</metric>
    <metric>count tents with [(my-age = "adult") and (infected? = true)]</metric>
    <metric>count tents with [(my-age = "elderly") and (infection = "symptomatic")]</metric>
    <metric>count tents with [(my-age = "child") and (infection = "symptomatic")]</metric>
    <metric>count tents with [(my-age = "adult") and (infection = "symptomatic")]</metric>
    <metric>count tents with [(my-age = "elderly") and (infection = "severely-symptomatic")]</metric>
    <metric>count tents with [(my-age = "child") and (infection = "severely-symptomatic")]</metric>
    <metric>count tents with [(my-age = "adult") and (infection = "severely-symptomatic")]</metric>
    <metric>count tents with [(my-age = "elderly") and (infection = "critical")]</metric>
    <metric>count tents with [(my-age = "child") and (infection = "critical")]</metric>
    <metric>count tents with [(my-age = "adult") and (infection = "critical")]</metric>
    <metric>count tents with [(my-age = "elderly") and (infection = "recovered")]</metric>
    <metric>count tents with [(my-age = "child") and (infection = "recovered")]</metric>
    <metric>count tents with [(my-age = "adult") and (infection = "recovered")]</metric>
    <metric>cum-dead</metric>
    <metric>cum-recovered</metric>
    <metric>[ic-capacity] of one-of covid-facilities</metric>
    <metric>[bed-capacity] of one-of covid-facilities</metric>
    <enumeratedValueSet variable="compliance">
      <value value="90"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="transmission-probability">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="household-size">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="plotsize-shelters">
      <value value="&quot;12,5 m2&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="factor-asymptomatic">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mobility">
      <value value="&quot;free&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poor-conditions?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="block-size">
      <value value="&quot;120 shelters&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="queue-distance">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-colors?">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Effect of 90%compliance quarantined-mobility (5x)" repetitions="5" runMetricsEveryStep="true">
    <setup>setup
initiate-corona
create-COVID-facility</setup>
    <go>go</go>
    <final>output-write infection-locations
output-write mobility
output-write compliance
output-write timer
export-output "output-mobility-compliance"
export-output (word "output-mobility_" mobility"_compliance_" compliance "_timer_" timer)</final>
    <timeLimit steps="72000"/>
    <metric>Day</metric>
    <metric>Hour</metric>
    <metric>count tents</metric>
    <metric>count tents with [(my-age = "elderly") and (infected? = true)]</metric>
    <metric>count tents with [(my-age = "child") and (infected? = true)]</metric>
    <metric>count tents with [(my-age = "adult") and (infected? = true)]</metric>
    <metric>count tents with [(my-age = "elderly") and (infection = "symptomatic")]</metric>
    <metric>count tents with [(my-age = "child") and (infection = "symptomatic")]</metric>
    <metric>count tents with [(my-age = "adult") and (infection = "symptomatic")]</metric>
    <metric>count tents with [(my-age = "elderly") and (infection = "severely-symptomatic")]</metric>
    <metric>count tents with [(my-age = "child") and (infection = "severely-symptomatic")]</metric>
    <metric>count tents with [(my-age = "adult") and (infection = "severely-symptomatic")]</metric>
    <metric>count tents with [(my-age = "elderly") and (infection = "critical")]</metric>
    <metric>count tents with [(my-age = "child") and (infection = "critical")]</metric>
    <metric>count tents with [(my-age = "adult") and (infection = "critical")]</metric>
    <metric>count tents with [(my-age = "elderly") and (infection = "recovered")]</metric>
    <metric>count tents with [(my-age = "child") and (infection = "recovered")]</metric>
    <metric>count tents with [(my-age = "adult") and (infection = "recovered")]</metric>
    <metric>cum-dead</metric>
    <metric>cum-recovered</metric>
    <metric>[ic-capacity] of one-of covid-facilities</metric>
    <metric>[bed-capacity] of one-of covid-facilities</metric>
    <enumeratedValueSet variable="compliance">
      <value value="90"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="transmission-probability">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="household-size">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="plotsize-shelters">
      <value value="&quot;12,5 m2&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="factor-asymptomatic">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mobility">
      <value value="&quot;quarantined&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poor-conditions?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="block-size">
      <value value="&quot;120 shelters&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="queue-distance">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-colors?">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Effect of 90%compliance isolation-mobility (5x)" repetitions="5" runMetricsEveryStep="true">
    <setup>setup
initiate-corona
create-COVID-facility</setup>
    <go>go</go>
    <final>output-write infection-locations
output-write mobility
output-write compliance
output-write timer
export-output "output-mobility-compliance"
export-output (word "output-mobility_" mobility"_compliance_" compliance "_timer_" timer)</final>
    <timeLimit steps="72000"/>
    <metric>Day</metric>
    <metric>Hour</metric>
    <metric>count tents</metric>
    <metric>count tents with [(my-age = "elderly") and (infected? = true)]</metric>
    <metric>count tents with [(my-age = "child") and (infected? = true)]</metric>
    <metric>count tents with [(my-age = "adult") and (infected? = true)]</metric>
    <metric>count tents with [(my-age = "elderly") and (infection = "symptomatic")]</metric>
    <metric>count tents with [(my-age = "child") and (infection = "symptomatic")]</metric>
    <metric>count tents with [(my-age = "adult") and (infection = "symptomatic")]</metric>
    <metric>count tents with [(my-age = "elderly") and (infection = "severely-symptomatic")]</metric>
    <metric>count tents with [(my-age = "child") and (infection = "severely-symptomatic")]</metric>
    <metric>count tents with [(my-age = "adult") and (infection = "severely-symptomatic")]</metric>
    <metric>count tents with [(my-age = "elderly") and (infection = "critical")]</metric>
    <metric>count tents with [(my-age = "child") and (infection = "critical")]</metric>
    <metric>count tents with [(my-age = "adult") and (infection = "critical")]</metric>
    <metric>count tents with [(my-age = "elderly") and (infection = "recovered")]</metric>
    <metric>count tents with [(my-age = "child") and (infection = "recovered")]</metric>
    <metric>count tents with [(my-age = "adult") and (infection = "recovered")]</metric>
    <metric>cum-dead</metric>
    <metric>cum-recovered</metric>
    <metric>[ic-capacity] of one-of covid-facilities</metric>
    <metric>[bed-capacity] of one-of covid-facilities</metric>
    <enumeratedValueSet variable="compliance">
      <value value="90"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="transmission-probability">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="household-size">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="plotsize-shelters">
      <value value="&quot;12,5 m2&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="factor-asymptomatic">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mobility">
      <value value="&quot;isolation&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poor-conditions?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="block-size">
      <value value="&quot;120 shelters&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="queue-distance">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-colors?">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Effect of 90%compliance no-elderly-mobility (5x)" repetitions="5" runMetricsEveryStep="true">
    <setup>setup
initiate-corona
create-COVID-facility</setup>
    <go>go</go>
    <final>output-write infection-locations
output-write mobility
output-write compliance
output-write timer
export-output "output-mobility-compliance"
export-output (word "output-mobility_" mobility"_compliance_" compliance "_timer_" timer)</final>
    <timeLimit steps="72000"/>
    <metric>Day</metric>
    <metric>Hour</metric>
    <metric>count tents</metric>
    <metric>count tents with [(my-age = "elderly") and (infected? = true)]</metric>
    <metric>count tents with [(my-age = "child") and (infected? = true)]</metric>
    <metric>count tents with [(my-age = "adult") and (infected? = true)]</metric>
    <metric>count tents with [(my-age = "elderly") and (infection = "symptomatic")]</metric>
    <metric>count tents with [(my-age = "child") and (infection = "symptomatic")]</metric>
    <metric>count tents with [(my-age = "adult") and (infection = "symptomatic")]</metric>
    <metric>count tents with [(my-age = "elderly") and (infection = "severely-symptomatic")]</metric>
    <metric>count tents with [(my-age = "child") and (infection = "severely-symptomatic")]</metric>
    <metric>count tents with [(my-age = "adult") and (infection = "severely-symptomatic")]</metric>
    <metric>count tents with [(my-age = "elderly") and (infection = "critical")]</metric>
    <metric>count tents with [(my-age = "child") and (infection = "critical")]</metric>
    <metric>count tents with [(my-age = "adult") and (infection = "critical")]</metric>
    <metric>count tents with [(my-age = "elderly") and (infection = "recovered")]</metric>
    <metric>count tents with [(my-age = "child") and (infection = "recovered")]</metric>
    <metric>count tents with [(my-age = "adult") and (infection = "recovered")]</metric>
    <metric>cum-dead</metric>
    <metric>cum-recovered</metric>
    <metric>[ic-capacity] of one-of covid-facilities</metric>
    <metric>[bed-capacity] of one-of covid-facilities</metric>
    <enumeratedValueSet variable="compliance">
      <value value="90"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="transmission-probability">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="household-size">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="plotsize-shelters">
      <value value="&quot;12,5 m2&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="factor-asymptomatic">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mobility">
      <value value="&quot;no-elderly&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poor-conditions?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="block-size">
      <value value="&quot;120 shelters&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="queue-distance">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-colors?">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Effect of1.5m queue-distance free-mobility (5x)" repetitions="5" runMetricsEveryStep="true">
    <setup>setup
initiate-corona
create-COVID-facility</setup>
    <go>go</go>
    <final>output-write infection-locations
output-write mobility
output-write queue-distance
output-write timer
export-output "output-mobility-queuedistance"
export-output (word "output-mobility_" mobility"_queue-distance_" queue-distance "_timer_" timer)</final>
    <timeLimit steps="72000"/>
    <metric>Day</metric>
    <metric>Hour</metric>
    <metric>count tents</metric>
    <metric>count tents with [(my-age = "elderly") and (infected? = true)]</metric>
    <metric>count tents with [(my-age = "child") and (infected? = true)]</metric>
    <metric>count tents with [(my-age = "adult") and (infected? = true)]</metric>
    <metric>count tents with [(my-age = "elderly") and (infection = "symptomatic")]</metric>
    <metric>count tents with [(my-age = "child") and (infection = "symptomatic")]</metric>
    <metric>count tents with [(my-age = "adult") and (infection = "symptomatic")]</metric>
    <metric>count tents with [(my-age = "elderly") and (infection = "severely-symptomatic")]</metric>
    <metric>count tents with [(my-age = "child") and (infection = "severely-symptomatic")]</metric>
    <metric>count tents with [(my-age = "adult") and (infection = "severely-symptomatic")]</metric>
    <metric>count tents with [(my-age = "elderly") and (infection = "critical")]</metric>
    <metric>count tents with [(my-age = "child") and (infection = "critical")]</metric>
    <metric>count tents with [(my-age = "adult") and (infection = "critical")]</metric>
    <metric>count tents with [(my-age = "elderly") and (infection = "recovered")]</metric>
    <metric>count tents with [(my-age = "child") and (infection = "recovered")]</metric>
    <metric>count tents with [(my-age = "adult") and (infection = "recovered")]</metric>
    <metric>cum-dead</metric>
    <metric>cum-recovered</metric>
    <metric>[ic-capacity] of one-of covid-facilities</metric>
    <metric>[bed-capacity] of one-of covid-facilities</metric>
    <enumeratedValueSet variable="compliance">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="transmission-probability">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="household-size">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="plotsize-shelters">
      <value value="&quot;12,5 m2&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="factor-asymptomatic">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mobility">
      <value value="&quot;free&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poor-conditions?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="block-size">
      <value value="&quot;120 shelters&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="queue-distance">
      <value value="1.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-colors?">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Effect of1.5m queue-distance isolation-mobility (5x)" repetitions="5" runMetricsEveryStep="true">
    <setup>setup
initiate-corona
create-COVID-facility</setup>
    <go>go</go>
    <final>output-write infection-locations
output-write mobility
output-write queue-distance
output-write timer
export-output "output-mobility-queuedistance"
export-output (word "output-mobility_" mobility"_queue-distance_" queue-distance "_timer_" timer)</final>
    <timeLimit steps="72000"/>
    <metric>Day</metric>
    <metric>Hour</metric>
    <metric>count tents</metric>
    <metric>count tents with [(my-age = "elderly") and (infected? = true)]</metric>
    <metric>count tents with [(my-age = "child") and (infected? = true)]</metric>
    <metric>count tents with [(my-age = "adult") and (infected? = true)]</metric>
    <metric>count tents with [(my-age = "elderly") and (infection = "symptomatic")]</metric>
    <metric>count tents with [(my-age = "child") and (infection = "symptomatic")]</metric>
    <metric>count tents with [(my-age = "adult") and (infection = "symptomatic")]</metric>
    <metric>count tents with [(my-age = "elderly") and (infection = "severely-symptomatic")]</metric>
    <metric>count tents with [(my-age = "child") and (infection = "severely-symptomatic")]</metric>
    <metric>count tents with [(my-age = "adult") and (infection = "severely-symptomatic")]</metric>
    <metric>count tents with [(my-age = "elderly") and (infection = "critical")]</metric>
    <metric>count tents with [(my-age = "child") and (infection = "critical")]</metric>
    <metric>count tents with [(my-age = "adult") and (infection = "critical")]</metric>
    <metric>count tents with [(my-age = "elderly") and (infection = "recovered")]</metric>
    <metric>count tents with [(my-age = "child") and (infection = "recovered")]</metric>
    <metric>count tents with [(my-age = "adult") and (infection = "recovered")]</metric>
    <metric>cum-dead</metric>
    <metric>cum-recovered</metric>
    <metric>[ic-capacity] of one-of covid-facilities</metric>
    <metric>[bed-capacity] of one-of covid-facilities</metric>
    <enumeratedValueSet variable="compliance">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="transmission-probability">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="household-size">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="plotsize-shelters">
      <value value="&quot;12,5 m2&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="factor-asymptomatic">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mobility">
      <value value="&quot;isolation&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poor-conditions?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="block-size">
      <value value="&quot;120 shelters&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="queue-distance">
      <value value="1.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-colors?">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Effect of 0.5m queue-distance quarantined-mobility (5x)" repetitions="5" runMetricsEveryStep="true">
    <setup>setup
initiate-corona
create-COVID-facility</setup>
    <go>go</go>
    <final>output-write infection-locations
output-write mobility
output-write queue-distance
output-write timer
export-output "output-mobility-queuedistance"
export-output (word "output-mobility_" mobility"_queue-distance_" queue-distance "_timer_" timer)</final>
    <timeLimit steps="72000"/>
    <metric>Day</metric>
    <metric>Hour</metric>
    <metric>count tents</metric>
    <metric>count tents with [(my-age = "elderly") and (infected? = true)]</metric>
    <metric>count tents with [(my-age = "child") and (infected? = true)]</metric>
    <metric>count tents with [(my-age = "adult") and (infected? = true)]</metric>
    <metric>count tents with [(my-age = "elderly") and (infection = "symptomatic")]</metric>
    <metric>count tents with [(my-age = "child") and (infection = "symptomatic")]</metric>
    <metric>count tents with [(my-age = "adult") and (infection = "symptomatic")]</metric>
    <metric>count tents with [(my-age = "elderly") and (infection = "severely-symptomatic")]</metric>
    <metric>count tents with [(my-age = "child") and (infection = "severely-symptomatic")]</metric>
    <metric>count tents with [(my-age = "adult") and (infection = "severely-symptomatic")]</metric>
    <metric>count tents with [(my-age = "elderly") and (infection = "critical")]</metric>
    <metric>count tents with [(my-age = "child") and (infection = "critical")]</metric>
    <metric>count tents with [(my-age = "adult") and (infection = "critical")]</metric>
    <metric>count tents with [(my-age = "elderly") and (infection = "recovered")]</metric>
    <metric>count tents with [(my-age = "child") and (infection = "recovered")]</metric>
    <metric>count tents with [(my-age = "adult") and (infection = "recovered")]</metric>
    <metric>cum-dead</metric>
    <metric>cum-recovered</metric>
    <metric>[ic-capacity] of one-of covid-facilities</metric>
    <metric>[bed-capacity] of one-of covid-facilities</metric>
    <enumeratedValueSet variable="compliance">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="transmission-probability">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="household-size">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="plotsize-shelters">
      <value value="&quot;12,5 m2&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="factor-asymptomatic">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mobility">
      <value value="&quot;quarantined&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poor-conditions?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="block-size">
      <value value="&quot;120 shelters&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="queue-distance">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-colors?">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Effect of1.5m queue-distance no-elderly-mobility (5x)" repetitions="5" runMetricsEveryStep="true">
    <setup>setup
initiate-corona
create-COVID-facility</setup>
    <go>go</go>
    <final>output-write infection-locations
output-write mobility
output-write queue-distance
output-write timer
export-output "output-mobility-queuedistance"
export-output (word "output-mobility_" mobility"_queue-distance_" queue-distance "_timer_" timer)</final>
    <timeLimit steps="72000"/>
    <metric>Day</metric>
    <metric>Hour</metric>
    <metric>count tents</metric>
    <metric>count tents with [(my-age = "elderly") and (infected? = true)]</metric>
    <metric>count tents with [(my-age = "child") and (infected? = true)]</metric>
    <metric>count tents with [(my-age = "adult") and (infected? = true)]</metric>
    <metric>count tents with [(my-age = "elderly") and (infection = "symptomatic")]</metric>
    <metric>count tents with [(my-age = "child") and (infection = "symptomatic")]</metric>
    <metric>count tents with [(my-age = "adult") and (infection = "symptomatic")]</metric>
    <metric>count tents with [(my-age = "elderly") and (infection = "severely-symptomatic")]</metric>
    <metric>count tents with [(my-age = "child") and (infection = "severely-symptomatic")]</metric>
    <metric>count tents with [(my-age = "adult") and (infection = "severely-symptomatic")]</metric>
    <metric>count tents with [(my-age = "elderly") and (infection = "critical")]</metric>
    <metric>count tents with [(my-age = "child") and (infection = "critical")]</metric>
    <metric>count tents with [(my-age = "adult") and (infection = "critical")]</metric>
    <metric>count tents with [(my-age = "elderly") and (infection = "recovered")]</metric>
    <metric>count tents with [(my-age = "child") and (infection = "recovered")]</metric>
    <metric>count tents with [(my-age = "adult") and (infection = "recovered")]</metric>
    <metric>cum-dead</metric>
    <metric>cum-recovered</metric>
    <metric>[ic-capacity] of one-of covid-facilities</metric>
    <metric>[bed-capacity] of one-of covid-facilities</metric>
    <enumeratedValueSet variable="compliance">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="transmission-probability">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="household-size">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="plotsize-shelters">
      <value value="&quot;12,5 m2&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="factor-asymptomatic">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mobility">
      <value value="&quot;no-elderly&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poor-conditions?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="block-size">
      <value value="&quot;120 shelters&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="queue-distance">
      <value value="1.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-colors?">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Effect of 0.5m queue-distance no-elderly-mobility (5x)" repetitions="5" runMetricsEveryStep="true">
    <setup>setup
initiate-corona
create-COVID-facility</setup>
    <go>go</go>
    <final>output-write infection-locations
output-write mobility
output-write queue-distance
output-write timer
export-output "output-mobility-queuedistance"
export-output (word "output-mobility_" mobility"_queue-distance_" queue-distance "_timer_" timer)</final>
    <timeLimit steps="72000"/>
    <metric>Day</metric>
    <metric>Hour</metric>
    <metric>count tents</metric>
    <metric>count tents with [(my-age = "elderly") and (infected? = true)]</metric>
    <metric>count tents with [(my-age = "child") and (infected? = true)]</metric>
    <metric>count tents with [(my-age = "adult") and (infected? = true)]</metric>
    <metric>count tents with [(my-age = "elderly") and (infection = "symptomatic")]</metric>
    <metric>count tents with [(my-age = "child") and (infection = "symptomatic")]</metric>
    <metric>count tents with [(my-age = "adult") and (infection = "symptomatic")]</metric>
    <metric>count tents with [(my-age = "elderly") and (infection = "severely-symptomatic")]</metric>
    <metric>count tents with [(my-age = "child") and (infection = "severely-symptomatic")]</metric>
    <metric>count tents with [(my-age = "adult") and (infection = "severely-symptomatic")]</metric>
    <metric>count tents with [(my-age = "elderly") and (infection = "critical")]</metric>
    <metric>count tents with [(my-age = "child") and (infection = "critical")]</metric>
    <metric>count tents with [(my-age = "adult") and (infection = "critical")]</metric>
    <metric>count tents with [(my-age = "elderly") and (infection = "recovered")]</metric>
    <metric>count tents with [(my-age = "child") and (infection = "recovered")]</metric>
    <metric>count tents with [(my-age = "adult") and (infection = "recovered")]</metric>
    <metric>cum-dead</metric>
    <metric>cum-recovered</metric>
    <metric>[ic-capacity] of one-of covid-facilities</metric>
    <metric>[bed-capacity] of one-of covid-facilities</metric>
    <enumeratedValueSet variable="compliance">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="transmission-probability">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="household-size">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="plotsize-shelters">
      <value value="&quot;12,5 m2&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="factor-asymptomatic">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mobility">
      <value value="&quot;no-elderly&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poor-conditions?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="block-size">
      <value value="&quot;120 shelters&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="queue-distance">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-colors?">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Effect of 0.5m queue-distance isolation-mobility (5x)" repetitions="5" runMetricsEveryStep="true">
    <setup>setup
initiate-corona
create-COVID-facility</setup>
    <go>go</go>
    <final>output-write infection-locations
output-write mobility
output-write queue-distance
output-write timer
export-output "output-mobility-queuedistance"
export-output (word "output-mobility_" mobility"_queue-distance_" queue-distance "_timer_" timer)</final>
    <timeLimit steps="72000"/>
    <metric>Day</metric>
    <metric>Hour</metric>
    <metric>count tents</metric>
    <metric>count tents with [(my-age = "elderly") and (infected? = true)]</metric>
    <metric>count tents with [(my-age = "child") and (infected? = true)]</metric>
    <metric>count tents with [(my-age = "adult") and (infected? = true)]</metric>
    <metric>count tents with [(my-age = "elderly") and (infection = "symptomatic")]</metric>
    <metric>count tents with [(my-age = "child") and (infection = "symptomatic")]</metric>
    <metric>count tents with [(my-age = "adult") and (infection = "symptomatic")]</metric>
    <metric>count tents with [(my-age = "elderly") and (infection = "severely-symptomatic")]</metric>
    <metric>count tents with [(my-age = "child") and (infection = "severely-symptomatic")]</metric>
    <metric>count tents with [(my-age = "adult") and (infection = "severely-symptomatic")]</metric>
    <metric>count tents with [(my-age = "elderly") and (infection = "critical")]</metric>
    <metric>count tents with [(my-age = "child") and (infection = "critical")]</metric>
    <metric>count tents with [(my-age = "adult") and (infection = "critical")]</metric>
    <metric>count tents with [(my-age = "elderly") and (infection = "recovered")]</metric>
    <metric>count tents with [(my-age = "child") and (infection = "recovered")]</metric>
    <metric>count tents with [(my-age = "adult") and (infection = "recovered")]</metric>
    <metric>cum-dead</metric>
    <metric>cum-recovered</metric>
    <metric>[ic-capacity] of one-of covid-facilities</metric>
    <metric>[bed-capacity] of one-of covid-facilities</metric>
    <enumeratedValueSet variable="compliance">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="transmission-probability">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="household-size">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="plotsize-shelters">
      <value value="&quot;12,5 m2&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="factor-asymptomatic">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mobility">
      <value value="&quot;isolation&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poor-conditions?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="block-size">
      <value value="&quot;120 shelters&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="queue-distance">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-colors?">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Effect of 0.5m queue-distance free-mobility (5x)" repetitions="5" runMetricsEveryStep="true">
    <setup>setup
initiate-corona
create-COVID-facility</setup>
    <go>go</go>
    <final>output-write infection-locations
output-write mobility
output-write queue-distance
output-write timer
export-output "output-mobility-queuedistance"
export-output (word "output-mobility_" mobility"_queue-distance_" queue-distance "_timer_" timer)</final>
    <timeLimit steps="72000"/>
    <metric>Day</metric>
    <metric>Hour</metric>
    <metric>count tents</metric>
    <metric>count tents with [(my-age = "elderly") and (infected? = true)]</metric>
    <metric>count tents with [(my-age = "child") and (infected? = true)]</metric>
    <metric>count tents with [(my-age = "adult") and (infected? = true)]</metric>
    <metric>count tents with [(my-age = "elderly") and (infection = "symptomatic")]</metric>
    <metric>count tents with [(my-age = "child") and (infection = "symptomatic")]</metric>
    <metric>count tents with [(my-age = "adult") and (infection = "symptomatic")]</metric>
    <metric>count tents with [(my-age = "elderly") and (infection = "severely-symptomatic")]</metric>
    <metric>count tents with [(my-age = "child") and (infection = "severely-symptomatic")]</metric>
    <metric>count tents with [(my-age = "adult") and (infection = "severely-symptomatic")]</metric>
    <metric>count tents with [(my-age = "elderly") and (infection = "critical")]</metric>
    <metric>count tents with [(my-age = "child") and (infection = "critical")]</metric>
    <metric>count tents with [(my-age = "adult") and (infection = "critical")]</metric>
    <metric>count tents with [(my-age = "elderly") and (infection = "recovered")]</metric>
    <metric>count tents with [(my-age = "child") and (infection = "recovered")]</metric>
    <metric>count tents with [(my-age = "adult") and (infection = "recovered")]</metric>
    <metric>cum-dead</metric>
    <metric>cum-recovered</metric>
    <metric>[ic-capacity] of one-of covid-facilities</metric>
    <metric>[bed-capacity] of one-of covid-facilities</metric>
    <enumeratedValueSet variable="compliance">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="transmission-probability">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="household-size">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="plotsize-shelters">
      <value value="&quot;12,5 m2&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="factor-asymptomatic">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mobility">
      <value value="&quot;free&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poor-conditions?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="block-size">
      <value value="&quot;120 shelters&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="queue-distance">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-colors?">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Effect of plotsize-25 free-mobility (5x)" repetitions="5" runMetricsEveryStep="true">
    <setup>setup
initiate-corona
create-COVID-facility</setup>
    <go>go</go>
    <final>output-write infection-locations
output-write mobility
output-write plotsize-shelters
output-write timer
export-output "output-mobility-plotsize-shelters"
export-output (word "output-mobility_" mobility"_plotsize-shelters_" plotsize-shelters "_timer_" timer)</final>
    <timeLimit steps="72000"/>
    <metric>Day</metric>
    <metric>Hour</metric>
    <metric>count tents</metric>
    <metric>count tents with [(my-age = "elderly") and (infected? = true)]</metric>
    <metric>count tents with [(my-age = "child") and (infected? = true)]</metric>
    <metric>count tents with [(my-age = "adult") and (infected? = true)]</metric>
    <metric>count tents with [(my-age = "elderly") and (infection = "symptomatic")]</metric>
    <metric>count tents with [(my-age = "child") and (infection = "symptomatic")]</metric>
    <metric>count tents with [(my-age = "adult") and (infection = "symptomatic")]</metric>
    <metric>count tents with [(my-age = "elderly") and (infection = "severely-symptomatic")]</metric>
    <metric>count tents with [(my-age = "child") and (infection = "severely-symptomatic")]</metric>
    <metric>count tents with [(my-age = "adult") and (infection = "severely-symptomatic")]</metric>
    <metric>count tents with [(my-age = "elderly") and (infection = "critical")]</metric>
    <metric>count tents with [(my-age = "child") and (infection = "critical")]</metric>
    <metric>count tents with [(my-age = "adult") and (infection = "critical")]</metric>
    <metric>count tents with [(my-age = "elderly") and (infection = "recovered")]</metric>
    <metric>count tents with [(my-age = "child") and (infection = "recovered")]</metric>
    <metric>count tents with [(my-age = "adult") and (infection = "recovered")]</metric>
    <metric>cum-dead</metric>
    <metric>cum-recovered</metric>
    <metric>[ic-capacity] of one-of covid-facilities</metric>
    <metric>[bed-capacity] of one-of covid-facilities</metric>
    <enumeratedValueSet variable="compliance">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="transmission-probability">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="household-size">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="plotsize-shelters">
      <value value="&quot;25 m2&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="factor-asymptomatic">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mobility">
      <value value="&quot;free&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poor-conditions?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="block-size">
      <value value="&quot;120 shelters&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="queue-distance">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-colors?">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Effect of plotsize-25 isolation-mobility (5x)" repetitions="5" runMetricsEveryStep="true">
    <setup>setup
initiate-corona
create-COVID-facility</setup>
    <go>go</go>
    <final>output-write infection-locations
output-write mobility
output-write plotsize-shelters
output-write timer
export-output "output-mobility-plotsize-shelters"
export-output (word "output-mobility_" mobility"_plotsize-shelters_" plotsize-shelters "_timer_" timer)</final>
    <timeLimit steps="72000"/>
    <metric>Day</metric>
    <metric>Hour</metric>
    <metric>count tents</metric>
    <metric>count tents with [(my-age = "elderly") and (infected? = true)]</metric>
    <metric>count tents with [(my-age = "child") and (infected? = true)]</metric>
    <metric>count tents with [(my-age = "adult") and (infected? = true)]</metric>
    <metric>count tents with [(my-age = "elderly") and (infection = "symptomatic")]</metric>
    <metric>count tents with [(my-age = "child") and (infection = "symptomatic")]</metric>
    <metric>count tents with [(my-age = "adult") and (infection = "symptomatic")]</metric>
    <metric>count tents with [(my-age = "elderly") and (infection = "severely-symptomatic")]</metric>
    <metric>count tents with [(my-age = "child") and (infection = "severely-symptomatic")]</metric>
    <metric>count tents with [(my-age = "adult") and (infection = "severely-symptomatic")]</metric>
    <metric>count tents with [(my-age = "elderly") and (infection = "critical")]</metric>
    <metric>count tents with [(my-age = "child") and (infection = "critical")]</metric>
    <metric>count tents with [(my-age = "adult") and (infection = "critical")]</metric>
    <metric>count tents with [(my-age = "elderly") and (infection = "recovered")]</metric>
    <metric>count tents with [(my-age = "child") and (infection = "recovered")]</metric>
    <metric>count tents with [(my-age = "adult") and (infection = "recovered")]</metric>
    <metric>cum-dead</metric>
    <metric>cum-recovered</metric>
    <metric>[ic-capacity] of one-of covid-facilities</metric>
    <metric>[bed-capacity] of one-of covid-facilities</metric>
    <enumeratedValueSet variable="compliance">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="transmission-probability">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="household-size">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="plotsize-shelters">
      <value value="&quot;25 m2&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="factor-asymptomatic">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mobility">
      <value value="&quot;isolation&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poor-conditions?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="block-size">
      <value value="&quot;120 shelters&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="queue-distance">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-colors?">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Effect of plotsize-25 no-elderly-mobility (5x)" repetitions="5" runMetricsEveryStep="true">
    <setup>setup
initiate-corona
create-COVID-facility</setup>
    <go>go</go>
    <final>output-write infection-locations
output-write mobility
output-write plotsize-shelters
output-write timer
export-output "output-mobility-plotsize-shelters"
export-output (word "output-mobility_" mobility"_plotsize-shelters_" plotsize-shelters "_timer_" timer)</final>
    <timeLimit steps="72000"/>
    <metric>Day</metric>
    <metric>Hour</metric>
    <metric>count tents</metric>
    <metric>count tents with [(my-age = "elderly") and (infected? = true)]</metric>
    <metric>count tents with [(my-age = "child") and (infected? = true)]</metric>
    <metric>count tents with [(my-age = "adult") and (infected? = true)]</metric>
    <metric>count tents with [(my-age = "elderly") and (infection = "symptomatic")]</metric>
    <metric>count tents with [(my-age = "child") and (infection = "symptomatic")]</metric>
    <metric>count tents with [(my-age = "adult") and (infection = "symptomatic")]</metric>
    <metric>count tents with [(my-age = "elderly") and (infection = "severely-symptomatic")]</metric>
    <metric>count tents with [(my-age = "child") and (infection = "severely-symptomatic")]</metric>
    <metric>count tents with [(my-age = "adult") and (infection = "severely-symptomatic")]</metric>
    <metric>count tents with [(my-age = "elderly") and (infection = "critical")]</metric>
    <metric>count tents with [(my-age = "child") and (infection = "critical")]</metric>
    <metric>count tents with [(my-age = "adult") and (infection = "critical")]</metric>
    <metric>count tents with [(my-age = "elderly") and (infection = "recovered")]</metric>
    <metric>count tents with [(my-age = "child") and (infection = "recovered")]</metric>
    <metric>count tents with [(my-age = "adult") and (infection = "recovered")]</metric>
    <metric>cum-dead</metric>
    <metric>cum-recovered</metric>
    <metric>[ic-capacity] of one-of covid-facilities</metric>
    <metric>[bed-capacity] of one-of covid-facilities</metric>
    <enumeratedValueSet variable="compliance">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="transmission-probability">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="household-size">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="plotsize-shelters">
      <value value="&quot;25 m2&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="factor-asymptomatic">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mobility">
      <value value="&quot;no-elderly&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poor-conditions?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="block-size">
      <value value="&quot;120 shelters&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="queue-distance">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-colors?">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Effect of plotsize-25 quarantined-mobility (5x)" repetitions="5" runMetricsEveryStep="true">
    <setup>setup
initiate-corona
create-COVID-facility</setup>
    <go>go</go>
    <final>output-write infection-locations
output-write mobility
output-write plotsize-shelters
output-write timer
export-output "output-mobility-plotsize-shelters"
export-output (word "output-mobility_" mobility"_plotsize-shelters_" plotsize-shelters "_timer_" timer)</final>
    <timeLimit steps="72000"/>
    <metric>Day</metric>
    <metric>Hour</metric>
    <metric>count tents</metric>
    <metric>count tents with [(my-age = "elderly") and (infected? = true)]</metric>
    <metric>count tents with [(my-age = "child") and (infected? = true)]</metric>
    <metric>count tents with [(my-age = "adult") and (infected? = true)]</metric>
    <metric>count tents with [(my-age = "elderly") and (infection = "symptomatic")]</metric>
    <metric>count tents with [(my-age = "child") and (infection = "symptomatic")]</metric>
    <metric>count tents with [(my-age = "adult") and (infection = "symptomatic")]</metric>
    <metric>count tents with [(my-age = "elderly") and (infection = "severely-symptomatic")]</metric>
    <metric>count tents with [(my-age = "child") and (infection = "severely-symptomatic")]</metric>
    <metric>count tents with [(my-age = "adult") and (infection = "severely-symptomatic")]</metric>
    <metric>count tents with [(my-age = "elderly") and (infection = "critical")]</metric>
    <metric>count tents with [(my-age = "child") and (infection = "critical")]</metric>
    <metric>count tents with [(my-age = "adult") and (infection = "critical")]</metric>
    <metric>count tents with [(my-age = "elderly") and (infection = "recovered")]</metric>
    <metric>count tents with [(my-age = "child") and (infection = "recovered")]</metric>
    <metric>count tents with [(my-age = "adult") and (infection = "recovered")]</metric>
    <metric>cum-dead</metric>
    <metric>cum-recovered</metric>
    <metric>[ic-capacity] of one-of covid-facilities</metric>
    <metric>[bed-capacity] of one-of covid-facilities</metric>
    <enumeratedValueSet variable="compliance">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="transmission-probability">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="household-size">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="plotsize-shelters">
      <value value="&quot;25 m2&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="factor-asymptomatic">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mobility">
      <value value="&quot;quarantined&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poor-conditions?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="block-size">
      <value value="&quot;120 shelters&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="queue-distance">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-colors?">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Effect of free-mobility (5x)" repetitions="5" runMetricsEveryStep="true">
    <setup>setup
initiate-corona
create-COVID-facility</setup>
    <go>go</go>
    <final>output-write infection-locations
output-write mobility
output-write timer
export-output "output-mobility"
export-output (word "output-mobility_" mobility "_timer_" timer)</final>
    <timeLimit steps="72000"/>
    <metric>Day</metric>
    <metric>Hour</metric>
    <metric>count tents</metric>
    <metric>count tents with [(my-age = "elderly") and (infected? = true)]</metric>
    <metric>count tents with [(my-age = "child") and (infected? = true)]</metric>
    <metric>count tents with [(my-age = "adult") and (infected? = true)]</metric>
    <metric>count tents with [(my-age = "elderly") and (infection = "symptomatic")]</metric>
    <metric>count tents with [(my-age = "child") and (infection = "symptomatic")]</metric>
    <metric>count tents with [(my-age = "adult") and (infection = "symptomatic")]</metric>
    <metric>count tents with [(my-age = "elderly") and (infection = "severely-symptomatic")]</metric>
    <metric>count tents with [(my-age = "child") and (infection = "severely-symptomatic")]</metric>
    <metric>count tents with [(my-age = "adult") and (infection = "severely-symptomatic")]</metric>
    <metric>count tents with [(my-age = "elderly") and (infection = "critical")]</metric>
    <metric>count tents with [(my-age = "child") and (infection = "critical")]</metric>
    <metric>count tents with [(my-age = "adult") and (infection = "critical")]</metric>
    <metric>count tents with [(my-age = "elderly") and (infection = "recovered")]</metric>
    <metric>count tents with [(my-age = "child") and (infection = "recovered")]</metric>
    <metric>count tents with [(my-age = "adult") and (infection = "recovered")]</metric>
    <metric>cum-dead</metric>
    <metric>cum-recovered</metric>
    <metric>[ic-capacity] of one-of covid-facilities</metric>
    <metric>[bed-capacity] of one-of covid-facilities</metric>
    <enumeratedValueSet variable="compliance">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="transmission-probability">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="household-size">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="plotsize-shelters">
      <value value="&quot;12,5 m2&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="factor-asymptomatic">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mobility">
      <value value="&quot;free&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poor-conditions?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="block-size">
      <value value="&quot;120 shelters&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="queue-distance">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-colors?">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Effect of quarantined-mobility (5x)" repetitions="5" runMetricsEveryStep="true">
    <setup>setup
initiate-corona
create-COVID-facility</setup>
    <go>go</go>
    <final>output-write infection-locations
output-write mobility
output-write timer
export-output "output-mobility"
export-output (word "output-mobility_" mobility"_timer_" timer)</final>
    <timeLimit steps="72000"/>
    <metric>Day</metric>
    <metric>Hour</metric>
    <metric>count tents</metric>
    <metric>count tents with [(my-age = "elderly") and (infected? = true)]</metric>
    <metric>count tents with [(my-age = "child") and (infected? = true)]</metric>
    <metric>count tents with [(my-age = "adult") and (infected? = true)]</metric>
    <metric>count tents with [(my-age = "elderly") and (infection = "symptomatic")]</metric>
    <metric>count tents with [(my-age = "child") and (infection = "symptomatic")]</metric>
    <metric>count tents with [(my-age = "adult") and (infection = "symptomatic")]</metric>
    <metric>count tents with [(my-age = "elderly") and (infection = "severely-symptomatic")]</metric>
    <metric>count tents with [(my-age = "child") and (infection = "severely-symptomatic")]</metric>
    <metric>count tents with [(my-age = "adult") and (infection = "severely-symptomatic")]</metric>
    <metric>count tents with [(my-age = "elderly") and (infection = "critical")]</metric>
    <metric>count tents with [(my-age = "child") and (infection = "critical")]</metric>
    <metric>count tents with [(my-age = "adult") and (infection = "critical")]</metric>
    <metric>count tents with [(my-age = "elderly") and (infection = "recovered")]</metric>
    <metric>count tents with [(my-age = "child") and (infection = "recovered")]</metric>
    <metric>count tents with [(my-age = "adult") and (infection = "recovered")]</metric>
    <metric>cum-dead</metric>
    <metric>cum-recovered</metric>
    <metric>[ic-capacity] of one-of covid-facilities</metric>
    <metric>[bed-capacity] of one-of covid-facilities</metric>
    <enumeratedValueSet variable="compliance">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="transmission-probability">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="household-size">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="plotsize-shelters">
      <value value="&quot;12,5 m2&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="factor-asymptomatic">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mobility">
      <value value="&quot;quarantined&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poor-conditions?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="block-size">
      <value value="&quot;120 shelters&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="queue-distance">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-colors?">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Effect of isolation-mobility (5x)" repetitions="5" runMetricsEveryStep="true">
    <setup>setup
initiate-corona
create-COVID-facility</setup>
    <go>go</go>
    <final>output-write infection-locations
output-write mobility
output-write timer
export-output "output-mobility"
export-output (word "output-mobility_" mobility"_timer_" timer)</final>
    <timeLimit steps="72000"/>
    <metric>Day</metric>
    <metric>Hour</metric>
    <metric>count tents</metric>
    <metric>count tents with [(my-age = "elderly") and (infected? = true)]</metric>
    <metric>count tents with [(my-age = "child") and (infected? = true)]</metric>
    <metric>count tents with [(my-age = "adult") and (infected? = true)]</metric>
    <metric>count tents with [(my-age = "elderly") and (infection = "symptomatic")]</metric>
    <metric>count tents with [(my-age = "child") and (infection = "symptomatic")]</metric>
    <metric>count tents with [(my-age = "adult") and (infection = "symptomatic")]</metric>
    <metric>count tents with [(my-age = "elderly") and (infection = "severely-symptomatic")]</metric>
    <metric>count tents with [(my-age = "child") and (infection = "severely-symptomatic")]</metric>
    <metric>count tents with [(my-age = "adult") and (infection = "severely-symptomatic")]</metric>
    <metric>count tents with [(my-age = "elderly") and (infection = "critical")]</metric>
    <metric>count tents with [(my-age = "child") and (infection = "critical")]</metric>
    <metric>count tents with [(my-age = "adult") and (infection = "critical")]</metric>
    <metric>count tents with [(my-age = "elderly") and (infection = "recovered")]</metric>
    <metric>count tents with [(my-age = "child") and (infection = "recovered")]</metric>
    <metric>count tents with [(my-age = "adult") and (infection = "recovered")]</metric>
    <metric>cum-dead</metric>
    <metric>cum-recovered</metric>
    <metric>[ic-capacity] of one-of covid-facilities</metric>
    <metric>[bed-capacity] of one-of covid-facilities</metric>
    <enumeratedValueSet variable="compliance">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="transmission-probability">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="household-size">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="plotsize-shelters">
      <value value="&quot;12,5 m2&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="factor-asymptomatic">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mobility">
      <value value="&quot;isolation&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poor-conditions?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="block-size">
      <value value="&quot;120 shelters&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="queue-distance">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-colors?">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Effect of no-elderly-mobility (5x)" repetitions="5" runMetricsEveryStep="true">
    <setup>setup
initiate-corona
create-COVID-facility</setup>
    <go>go</go>
    <final>output-write infection-locations
output-write mobility
output-write timer
export-output "output-mobility-compliance"
export-output (word "output-mobility_" mobility"_timer_" timer)</final>
    <timeLimit steps="72000"/>
    <metric>Day</metric>
    <metric>Hour</metric>
    <metric>count tents</metric>
    <metric>count tents with [(my-age = "elderly") and (infected? = true)]</metric>
    <metric>count tents with [(my-age = "child") and (infected? = true)]</metric>
    <metric>count tents with [(my-age = "adult") and (infected? = true)]</metric>
    <metric>count tents with [(my-age = "elderly") and (infection = "symptomatic")]</metric>
    <metric>count tents with [(my-age = "child") and (infection = "symptomatic")]</metric>
    <metric>count tents with [(my-age = "adult") and (infection = "symptomatic")]</metric>
    <metric>count tents with [(my-age = "elderly") and (infection = "severely-symptomatic")]</metric>
    <metric>count tents with [(my-age = "child") and (infection = "severely-symptomatic")]</metric>
    <metric>count tents with [(my-age = "adult") and (infection = "severely-symptomatic")]</metric>
    <metric>count tents with [(my-age = "elderly") and (infection = "critical")]</metric>
    <metric>count tents with [(my-age = "child") and (infection = "critical")]</metric>
    <metric>count tents with [(my-age = "adult") and (infection = "critical")]</metric>
    <metric>count tents with [(my-age = "elderly") and (infection = "recovered")]</metric>
    <metric>count tents with [(my-age = "child") and (infection = "recovered")]</metric>
    <metric>count tents with [(my-age = "adult") and (infection = "recovered")]</metric>
    <metric>cum-dead</metric>
    <metric>cum-recovered</metric>
    <metric>[ic-capacity] of one-of covid-facilities</metric>
    <metric>[bed-capacity] of one-of covid-facilities</metric>
    <enumeratedValueSet variable="compliance">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="transmission-probability">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="household-size">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="plotsize-shelters">
      <value value="&quot;12,5 m2&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="factor-asymptomatic">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mobility">
      <value value="&quot;no-elderly&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poor-conditions?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="block-size">
      <value value="&quot;120 shelters&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="queue-distance">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-colors?">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Effect of 1.5m queue-distance quarantined-mobility (5x)" repetitions="5" runMetricsEveryStep="true">
    <setup>setup
initiate-corona
create-COVID-facility</setup>
    <go>go</go>
    <final>output-write infection-locations
output-write mobility
output-write queue-distance
output-write timer
export-output "output-mobility-queuedistance"
export-output (word "output-mobility_" mobility"_queue-distance_" queue-distance "_timer_" timer)</final>
    <timeLimit steps="72000"/>
    <metric>Day</metric>
    <metric>Hour</metric>
    <metric>count tents</metric>
    <metric>count tents with [(my-age = "elderly") and (infected? = true)]</metric>
    <metric>count tents with [(my-age = "child") and (infected? = true)]</metric>
    <metric>count tents with [(my-age = "adult") and (infected? = true)]</metric>
    <metric>count tents with [(my-age = "elderly") and (infection = "symptomatic")]</metric>
    <metric>count tents with [(my-age = "child") and (infection = "symptomatic")]</metric>
    <metric>count tents with [(my-age = "adult") and (infection = "symptomatic")]</metric>
    <metric>count tents with [(my-age = "elderly") and (infection = "severely-symptomatic")]</metric>
    <metric>count tents with [(my-age = "child") and (infection = "severely-symptomatic")]</metric>
    <metric>count tents with [(my-age = "adult") and (infection = "severely-symptomatic")]</metric>
    <metric>count tents with [(my-age = "elderly") and (infection = "critical")]</metric>
    <metric>count tents with [(my-age = "child") and (infection = "critical")]</metric>
    <metric>count tents with [(my-age = "adult") and (infection = "critical")]</metric>
    <metric>count tents with [(my-age = "elderly") and (infection = "recovered")]</metric>
    <metric>count tents with [(my-age = "child") and (infection = "recovered")]</metric>
    <metric>count tents with [(my-age = "adult") and (infection = "recovered")]</metric>
    <metric>cum-dead</metric>
    <metric>cum-recovered</metric>
    <metric>[ic-capacity] of one-of covid-facilities</metric>
    <metric>[bed-capacity] of one-of covid-facilities</metric>
    <enumeratedValueSet variable="compliance">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="transmission-probability">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="household-size">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="plotsize-shelters">
      <value value="&quot;12,5 m2&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="factor-asymptomatic">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mobility">
      <value value="&quot;quarantined&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poor-conditions?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="block-size">
      <value value="&quot;120 shelters&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="queue-distance">
      <value value="1.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-colors?">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Effect of hhsize-7 free-mobility (5x)" repetitions="5" runMetricsEveryStep="true">
    <setup>setup
initiate-corona
create-COVID-facility</setup>
    <go>go</go>
    <final>output-write infection-locations
output-write mobility
output-write household-size
output-write timer
export-output "output-mobility"
export-output (word "output-mobility_" mobility "_household-size_" household-size "_timer_" timer)</final>
    <timeLimit steps="72000"/>
    <metric>Day</metric>
    <metric>Hour</metric>
    <metric>count tents</metric>
    <metric>count tents with [(my-age = "elderly") and (infected? = true)]</metric>
    <metric>count tents with [(my-age = "child") and (infected? = true)]</metric>
    <metric>count tents with [(my-age = "adult") and (infected? = true)]</metric>
    <metric>count tents with [(my-age = "elderly") and (infection = "symptomatic")]</metric>
    <metric>count tents with [(my-age = "child") and (infection = "symptomatic")]</metric>
    <metric>count tents with [(my-age = "adult") and (infection = "symptomatic")]</metric>
    <metric>count tents with [(my-age = "elderly") and (infection = "severely-symptomatic")]</metric>
    <metric>count tents with [(my-age = "child") and (infection = "severely-symptomatic")]</metric>
    <metric>count tents with [(my-age = "adult") and (infection = "severely-symptomatic")]</metric>
    <metric>count tents with [(my-age = "elderly") and (infection = "critical")]</metric>
    <metric>count tents with [(my-age = "child") and (infection = "critical")]</metric>
    <metric>count tents with [(my-age = "adult") and (infection = "critical")]</metric>
    <metric>count tents with [(my-age = "elderly") and (infection = "recovered")]</metric>
    <metric>count tents with [(my-age = "child") and (infection = "recovered")]</metric>
    <metric>count tents with [(my-age = "adult") and (infection = "recovered")]</metric>
    <metric>cum-dead</metric>
    <metric>cum-recovered</metric>
    <metric>[ic-capacity] of one-of covid-facilities</metric>
    <metric>[bed-capacity] of one-of covid-facilities</metric>
    <enumeratedValueSet variable="compliance">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="transmission-probability">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="household-size">
      <value value="7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="plotsize-shelters">
      <value value="&quot;12,5 m2&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="factor-asymptomatic">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mobility">
      <value value="&quot;free&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poor-conditions?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="block-size">
      <value value="&quot;120 shelters&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="queue-distance">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-colors?">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Effect of hhsize-7 isolation-mobility (5x)" repetitions="5" runMetricsEveryStep="true">
    <setup>setup
initiate-corona
create-COVID-facility</setup>
    <go>go</go>
    <final>output-write infection-locations
output-write mobility
output-write household-size
output-write timer
export-output "output-mobility"
export-output (word "output-mobility_" mobility "_household-size_" household-size "_timer_" timer)</final>
    <timeLimit steps="72000"/>
    <metric>Day</metric>
    <metric>Hour</metric>
    <metric>count tents</metric>
    <metric>count tents with [(my-age = "elderly") and (infected? = true)]</metric>
    <metric>count tents with [(my-age = "child") and (infected? = true)]</metric>
    <metric>count tents with [(my-age = "adult") and (infected? = true)]</metric>
    <metric>count tents with [(my-age = "elderly") and (infection = "symptomatic")]</metric>
    <metric>count tents with [(my-age = "child") and (infection = "symptomatic")]</metric>
    <metric>count tents with [(my-age = "adult") and (infection = "symptomatic")]</metric>
    <metric>count tents with [(my-age = "elderly") and (infection = "severely-symptomatic")]</metric>
    <metric>count tents with [(my-age = "child") and (infection = "severely-symptomatic")]</metric>
    <metric>count tents with [(my-age = "adult") and (infection = "severely-symptomatic")]</metric>
    <metric>count tents with [(my-age = "elderly") and (infection = "critical")]</metric>
    <metric>count tents with [(my-age = "child") and (infection = "critical")]</metric>
    <metric>count tents with [(my-age = "adult") and (infection = "critical")]</metric>
    <metric>count tents with [(my-age = "elderly") and (infection = "recovered")]</metric>
    <metric>count tents with [(my-age = "child") and (infection = "recovered")]</metric>
    <metric>count tents with [(my-age = "adult") and (infection = "recovered")]</metric>
    <metric>cum-dead</metric>
    <metric>cum-recovered</metric>
    <metric>[ic-capacity] of one-of covid-facilities</metric>
    <metric>[bed-capacity] of one-of covid-facilities</metric>
    <enumeratedValueSet variable="compliance">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="transmission-probability">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="household-size">
      <value value="7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="plotsize-shelters">
      <value value="&quot;12,5 m2&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="factor-asymptomatic">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mobility">
      <value value="&quot;isolation&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poor-conditions?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="block-size">
      <value value="&quot;120 shelters&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="queue-distance">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-colors?">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Effect of hhsize-7 no-elderly-mobility (5x)" repetitions="5" runMetricsEveryStep="true">
    <setup>setup
initiate-corona
create-COVID-facility</setup>
    <go>go</go>
    <final>output-write infection-locations
output-write mobility
output-write household-size
output-write timer
export-output "output-mobility"
export-output (word "output-mobility_" mobility "_household-size_" household-size "_timer_" timer)</final>
    <timeLimit steps="72000"/>
    <metric>Day</metric>
    <metric>Hour</metric>
    <metric>count tents</metric>
    <metric>count tents with [(my-age = "elderly") and (infected? = true)]</metric>
    <metric>count tents with [(my-age = "child") and (infected? = true)]</metric>
    <metric>count tents with [(my-age = "adult") and (infected? = true)]</metric>
    <metric>count tents with [(my-age = "elderly") and (infection = "symptomatic")]</metric>
    <metric>count tents with [(my-age = "child") and (infection = "symptomatic")]</metric>
    <metric>count tents with [(my-age = "adult") and (infection = "symptomatic")]</metric>
    <metric>count tents with [(my-age = "elderly") and (infection = "severely-symptomatic")]</metric>
    <metric>count tents with [(my-age = "child") and (infection = "severely-symptomatic")]</metric>
    <metric>count tents with [(my-age = "adult") and (infection = "severely-symptomatic")]</metric>
    <metric>count tents with [(my-age = "elderly") and (infection = "critical")]</metric>
    <metric>count tents with [(my-age = "child") and (infection = "critical")]</metric>
    <metric>count tents with [(my-age = "adult") and (infection = "critical")]</metric>
    <metric>count tents with [(my-age = "elderly") and (infection = "recovered")]</metric>
    <metric>count tents with [(my-age = "child") and (infection = "recovered")]</metric>
    <metric>count tents with [(my-age = "adult") and (infection = "recovered")]</metric>
    <metric>cum-dead</metric>
    <metric>cum-recovered</metric>
    <metric>[ic-capacity] of one-of covid-facilities</metric>
    <metric>[bed-capacity] of one-of covid-facilities</metric>
    <enumeratedValueSet variable="compliance">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="transmission-probability">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="household-size">
      <value value="7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="plotsize-shelters">
      <value value="&quot;12,5 m2&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="factor-asymptomatic">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mobility">
      <value value="&quot;no-elderly&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poor-conditions?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="block-size">
      <value value="&quot;120 shelters&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="queue-distance">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-colors?">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Effect of hhsize-7 quarantined-mobility (5x)" repetitions="5" runMetricsEveryStep="true">
    <setup>setup
initiate-corona
create-COVID-facility</setup>
    <go>go</go>
    <final>output-write infection-locations
output-write mobility
output-write household-size
output-write timer
export-output "output-mobility"
export-output (word "output-mobility_" mobility "_household-size_" household-size "_timer_" timer)</final>
    <timeLimit steps="72000"/>
    <metric>Day</metric>
    <metric>Hour</metric>
    <metric>count tents</metric>
    <metric>count tents with [(my-age = "elderly") and (infected? = true)]</metric>
    <metric>count tents with [(my-age = "child") and (infected? = true)]</metric>
    <metric>count tents with [(my-age = "adult") and (infected? = true)]</metric>
    <metric>count tents with [(my-age = "elderly") and (infection = "symptomatic")]</metric>
    <metric>count tents with [(my-age = "child") and (infection = "symptomatic")]</metric>
    <metric>count tents with [(my-age = "adult") and (infection = "symptomatic")]</metric>
    <metric>count tents with [(my-age = "elderly") and (infection = "severely-symptomatic")]</metric>
    <metric>count tents with [(my-age = "child") and (infection = "severely-symptomatic")]</metric>
    <metric>count tents with [(my-age = "adult") and (infection = "severely-symptomatic")]</metric>
    <metric>count tents with [(my-age = "elderly") and (infection = "critical")]</metric>
    <metric>count tents with [(my-age = "child") and (infection = "critical")]</metric>
    <metric>count tents with [(my-age = "adult") and (infection = "critical")]</metric>
    <metric>count tents with [(my-age = "elderly") and (infection = "recovered")]</metric>
    <metric>count tents with [(my-age = "child") and (infection = "recovered")]</metric>
    <metric>count tents with [(my-age = "adult") and (infection = "recovered")]</metric>
    <metric>cum-dead</metric>
    <metric>cum-recovered</metric>
    <metric>[ic-capacity] of one-of covid-facilities</metric>
    <metric>[bed-capacity] of one-of covid-facilities</metric>
    <enumeratedValueSet variable="compliance">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="transmission-probability">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="household-size">
      <value value="7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="plotsize-shelters">
      <value value="&quot;12,5 m2&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="factor-asymptomatic">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mobility">
      <value value="&quot;quarantined&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poor-conditions?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="block-size">
      <value value="&quot;120 shelters&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="queue-distance">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-colors?">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Effect of factor-asymptomatic-2 free-mobility (5x)" repetitions="5" runMetricsEveryStep="true">
    <setup>setup
initiate-corona
create-COVID-facility</setup>
    <go>go</go>
    <final>output-write infection-locations
output-write mobility
output-write factor-asymptomatic
output-write timer
export-output "output-mobility"
export-output (word "output-mobility_" mobility "_factor-asymptomatic_" factor-asymptomatic "_timer_" timer)</final>
    <timeLimit steps="72000"/>
    <metric>Day</metric>
    <metric>Hour</metric>
    <metric>count tents</metric>
    <metric>count tents with [(my-age = "elderly") and (infected? = true)]</metric>
    <metric>count tents with [(my-age = "child") and (infected? = true)]</metric>
    <metric>count tents with [(my-age = "adult") and (infected? = true)]</metric>
    <metric>count tents with [(my-age = "elderly") and (infection = "symptomatic")]</metric>
    <metric>count tents with [(my-age = "child") and (infection = "symptomatic")]</metric>
    <metric>count tents with [(my-age = "adult") and (infection = "symptomatic")]</metric>
    <metric>count tents with [(my-age = "elderly") and (infection = "severely-symptomatic")]</metric>
    <metric>count tents with [(my-age = "child") and (infection = "severely-symptomatic")]</metric>
    <metric>count tents with [(my-age = "adult") and (infection = "severely-symptomatic")]</metric>
    <metric>count tents with [(my-age = "elderly") and (infection = "critical")]</metric>
    <metric>count tents with [(my-age = "child") and (infection = "critical")]</metric>
    <metric>count tents with [(my-age = "adult") and (infection = "critical")]</metric>
    <metric>count tents with [(my-age = "elderly") and (infection = "recovered")]</metric>
    <metric>count tents with [(my-age = "child") and (infection = "recovered")]</metric>
    <metric>count tents with [(my-age = "adult") and (infection = "recovered")]</metric>
    <metric>cum-dead</metric>
    <metric>cum-recovered</metric>
    <metric>[ic-capacity] of one-of covid-facilities</metric>
    <metric>[bed-capacity] of one-of covid-facilities</metric>
    <enumeratedValueSet variable="compliance">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="transmission-probability">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="household-size">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="plotsize-shelters">
      <value value="&quot;12,5 m2&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="factor-asymptomatic">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mobility">
      <value value="&quot;free&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poor-conditions?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="block-size">
      <value value="&quot;120 shelters&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="queue-distance">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-colors?">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Effect of factor-asymptomatic-2 isolation-mobility (5x)" repetitions="5" runMetricsEveryStep="true">
    <setup>setup
initiate-corona
create-COVID-facility</setup>
    <go>go</go>
    <final>output-write infection-locations
output-write mobility
output-write factor-asymptomatic
output-write timer
export-output "output-mobility"
export-output (word "output-mobility_" mobility "_factor-asymptomatic_" factor-asymptomatic "_timer_" timer)</final>
    <timeLimit steps="72000"/>
    <metric>Day</metric>
    <metric>Hour</metric>
    <metric>count tents</metric>
    <metric>count tents with [(my-age = "elderly") and (infected? = true)]</metric>
    <metric>count tents with [(my-age = "child") and (infected? = true)]</metric>
    <metric>count tents with [(my-age = "adult") and (infected? = true)]</metric>
    <metric>count tents with [(my-age = "elderly") and (infection = "symptomatic")]</metric>
    <metric>count tents with [(my-age = "child") and (infection = "symptomatic")]</metric>
    <metric>count tents with [(my-age = "adult") and (infection = "symptomatic")]</metric>
    <metric>count tents with [(my-age = "elderly") and (infection = "severely-symptomatic")]</metric>
    <metric>count tents with [(my-age = "child") and (infection = "severely-symptomatic")]</metric>
    <metric>count tents with [(my-age = "adult") and (infection = "severely-symptomatic")]</metric>
    <metric>count tents with [(my-age = "elderly") and (infection = "critical")]</metric>
    <metric>count tents with [(my-age = "child") and (infection = "critical")]</metric>
    <metric>count tents with [(my-age = "adult") and (infection = "critical")]</metric>
    <metric>count tents with [(my-age = "elderly") and (infection = "recovered")]</metric>
    <metric>count tents with [(my-age = "child") and (infection = "recovered")]</metric>
    <metric>count tents with [(my-age = "adult") and (infection = "recovered")]</metric>
    <metric>cum-dead</metric>
    <metric>cum-recovered</metric>
    <metric>[ic-capacity] of one-of covid-facilities</metric>
    <metric>[bed-capacity] of one-of covid-facilities</metric>
    <enumeratedValueSet variable="compliance">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="transmission-probability">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="household-size">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="plotsize-shelters">
      <value value="&quot;12,5 m2&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="factor-asymptomatic">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mobility">
      <value value="&quot;isolation&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poor-conditions?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="block-size">
      <value value="&quot;120 shelters&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="queue-distance">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-colors?">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Effect of factor-asymptomatic-2 no-elderly-mobility (5x)" repetitions="5" runMetricsEveryStep="true">
    <setup>setup
initiate-corona
create-COVID-facility</setup>
    <go>go</go>
    <final>output-write infection-locations
output-write mobility
output-write factor-asymptomatic
output-write timer
export-output "output-mobility"
export-output (word "output-mobility_" mobility "_factor-asymptomatic_" factor-asymptomatic "_timer_" timer)</final>
    <timeLimit steps="72000"/>
    <metric>Day</metric>
    <metric>Hour</metric>
    <metric>count tents</metric>
    <metric>count tents with [(my-age = "elderly") and (infected? = true)]</metric>
    <metric>count tents with [(my-age = "child") and (infected? = true)]</metric>
    <metric>count tents with [(my-age = "adult") and (infected? = true)]</metric>
    <metric>count tents with [(my-age = "elderly") and (infection = "symptomatic")]</metric>
    <metric>count tents with [(my-age = "child") and (infection = "symptomatic")]</metric>
    <metric>count tents with [(my-age = "adult") and (infection = "symptomatic")]</metric>
    <metric>count tents with [(my-age = "elderly") and (infection = "severely-symptomatic")]</metric>
    <metric>count tents with [(my-age = "child") and (infection = "severely-symptomatic")]</metric>
    <metric>count tents with [(my-age = "adult") and (infection = "severely-symptomatic")]</metric>
    <metric>count tents with [(my-age = "elderly") and (infection = "critical")]</metric>
    <metric>count tents with [(my-age = "child") and (infection = "critical")]</metric>
    <metric>count tents with [(my-age = "adult") and (infection = "critical")]</metric>
    <metric>count tents with [(my-age = "elderly") and (infection = "recovered")]</metric>
    <metric>count tents with [(my-age = "child") and (infection = "recovered")]</metric>
    <metric>count tents with [(my-age = "adult") and (infection = "recovered")]</metric>
    <metric>cum-dead</metric>
    <metric>cum-recovered</metric>
    <metric>[ic-capacity] of one-of covid-facilities</metric>
    <metric>[bed-capacity] of one-of covid-facilities</metric>
    <enumeratedValueSet variable="compliance">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="transmission-probability">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="household-size">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="plotsize-shelters">
      <value value="&quot;12,5 m2&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="factor-asymptomatic">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mobility">
      <value value="&quot;no-elderly&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poor-conditions?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="block-size">
      <value value="&quot;120 shelters&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="queue-distance">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-colors?">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Effect of factor-asymptomatic-2 quarantined-mobility (5x)" repetitions="5" runMetricsEveryStep="true">
    <setup>setup
initiate-corona
create-COVID-facility</setup>
    <go>go</go>
    <final>output-write infection-locations
output-write mobility
output-write factor-asymptomatic
output-write timer
export-output "output-mobility"
export-output (word "output-mobility_" mobility "_factor-asymptomatic_" factor-asymptomatic "_timer_" timer)</final>
    <timeLimit steps="72000"/>
    <metric>Day</metric>
    <metric>Hour</metric>
    <metric>count tents</metric>
    <metric>count tents with [(my-age = "elderly") and (infected? = true)]</metric>
    <metric>count tents with [(my-age = "child") and (infected? = true)]</metric>
    <metric>count tents with [(my-age = "adult") and (infected? = true)]</metric>
    <metric>count tents with [(my-age = "elderly") and (infection = "symptomatic")]</metric>
    <metric>count tents with [(my-age = "child") and (infection = "symptomatic")]</metric>
    <metric>count tents with [(my-age = "adult") and (infection = "symptomatic")]</metric>
    <metric>count tents with [(my-age = "elderly") and (infection = "severely-symptomatic")]</metric>
    <metric>count tents with [(my-age = "child") and (infection = "severely-symptomatic")]</metric>
    <metric>count tents with [(my-age = "adult") and (infection = "severely-symptomatic")]</metric>
    <metric>count tents with [(my-age = "elderly") and (infection = "critical")]</metric>
    <metric>count tents with [(my-age = "child") and (infection = "critical")]</metric>
    <metric>count tents with [(my-age = "adult") and (infection = "critical")]</metric>
    <metric>count tents with [(my-age = "elderly") and (infection = "recovered")]</metric>
    <metric>count tents with [(my-age = "child") and (infection = "recovered")]</metric>
    <metric>count tents with [(my-age = "adult") and (infection = "recovered")]</metric>
    <metric>cum-dead</metric>
    <metric>cum-recovered</metric>
    <metric>[ic-capacity] of one-of covid-facilities</metric>
    <metric>[bed-capacity] of one-of covid-facilities</metric>
    <enumeratedValueSet variable="compliance">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="transmission-probability">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="household-size">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="plotsize-shelters">
      <value value="&quot;12,5 m2&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="factor-asymptomatic">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mobility">
      <value value="&quot;quarantined&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poor-conditions?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="block-size">
      <value value="&quot;120 shelters&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="queue-distance">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-colors?">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
