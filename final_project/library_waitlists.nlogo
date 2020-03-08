;; Create custom turtles and links
breed [patrons patron]
patrons-own [queue]

breed [books book]
books-own [status waitlist pointer]

undirected-link-breed [loans loan]
loans-own [pages-left ttl]

;; Declare global variabls
globals [numbooks numpatrons maxqueue booklength idlebooks idlepatrons]


to setup
  clear-all

  ;; Initialize global variables
  ;; These could be made into input parameters
  set numbooks 10
  set numpatrons 10
  set maxqueue 2
  set booklength 300

  ;; create inevntory of books
  foreach (range 0 numbooks)
    [ x -> create-books 1
      [ set status "ready"
        set shape "book"
        set size 2
        ;set color ((X * 10) + 5)
        set color grey
        set xcor ((x * 2) - numbooks)
        set ycor 10 ]
    ]

  ;; create population of patrons
  foreach (range 0 numpatrons)
    [ x -> create-patrons 1
      [ set queue (list ) ;; creates an empty list
        set shape "person"
        set color 36
        set size 2
        set xcor ((x * 2) - numpatrons) ]
    ]

  ;; populate each book's waitlist
  ask books [
    set waitlist sort patrons
    set pointer 0
    create-loans-with patrons [
      set color grey
      set thickness 0.125
      set pages-left booklength
    ]
  ]

  reset-ticks
end


to go
  ;; Library offers books to next patrons in waitlists
  ask books with [status = "ready"] [offer-book]

  ;; Patrons, queue, defer, and read books
  ask patrons [
    queue-or-defer-books
    read-books
  ]

  ;; System checks for idle books and idle patrons
  gather-stats

  ;; Library reclaims finished, due, and deferred books
  return-finished-books
  update-due-dates
  reclaim-due-books
  reclaim-deferred-books

  ;; Stop when all holds have been read
  if count loans = 0 [stop]
  tick
end


to offer-book
  ;; ignore if book has no holds
  if count my-loans = 0 [stop]
  ;; update status & color
  set status "offered"
  set color cyan
  ;; offer book to next person in the waitlist
  ;; this is indicated by making the link cyan
  ask loan-with item pointer waitlist [
    set color cyan
    set ttl 21
  ]
end


to queue-or-defer-books
  ;; ignore if no books offered to this patron
  if count my-loans with [color = cyan] = 0 [ stop ]
  ;; for all offered (cyan) loans, add to queue (and color red) or defer (and color yellow)
  foreach sort my-loans with [color = cyan] [new-loan ->
    ifelse AllowDefer = True and length queue >= maxqueue [
      ask new-loan [
        set color yellow
        ask end1 [
          set color yellow
          set status "deferred"
        ]
      ]
    ][
      set queue lput new-loan queue
      ask new-loan [
        set color red
        ask end1 [
          set color red
          set status "queued"
        ]
      ]

    ]
  ]
end


to read-books
  ;; ignore if no books in the patron's queue
  if length queue = 0 [stop]
  ;; read 20 pages from the first book in the queue only (and mark it active with green)
  ask first queue [
    set pages-left (pages-left - 20)
    set color green
    ask end1 [set color green]
  ]
end


to gather-stats
  ;; count idle books (in patron queues but not actively being read)
  set idlebooks count loans with [ color = red ]

  ;; coutn idle patrons (not actively reading even though they still have holds)
  set idlepatrons count patrons with [ (length queue) = 0 and count my-loans > 0]
end


to return-finished-books
  ;; if patron is finished ...
  ask loans with [pages-left < 1] [
    ask end1 [
      ;; remove patron from the book's waitlist and update the book's status (grey, ready)
      ;; set waitlist pointer to 0 (first person in the list)
      set waitlist remove-item pointer waitlist
      set pointer 0
      set status "ready"
      set color grey
    ]
    ask end2 [
      ;; remove the loan from the patron's queue
      set queue but-first queue
    ]
    ;; remove the hold/loan from the model
    die
  ]
end


to update-due-dates
  ;; decrement all loaned book's due dates by one
  ask loans with [color = green or color = red] [set ttl (ttl - 1)]
end


to reclaim-due-books
  ;; if loaned book is due (ttl = 0) ...
  ask loans with [(color = red or color = green) and ttl < 1] [
    set color grey
    ask end1 [
      ;; put the patron at the end of the waitlist (patron re-requests the book)
      ;; update book status (grey, ready)
      ;; move waitlist pointer to 0 (first person in the list)
      let p item pointer waitlist
      set waitlist remove-item pointer waitlist
      set waitlist lput p waitlist
      set pointer 0
      set status "ready"
      set color grey
    ]
    ask end2 [
      ;; remove the loan from the patron's queue
      set queue remove myself queue  ;; NOTE: myself refers to the calling agent, whereas self refers to the current agent
    ]
  ]
end


to reclaim-deferred-books
  ;; if a book is deferred (yellow)
  ask loans with [color = yellow] [
    set color grey
    ask end1 [
      ;; increment the book's waitlist pointer by one
      ;; Thus it will offer itself to the next patron without removing the previous patron from their position
      set pointer (pointer + 1)
      if pointer >= length waitlist [
        set pointer 0
      ]
      set status "ready"
      set color grey
    ]
  ]
end
@#$#@#$#@
GRAPHICS-WINDOW
210
10
647
448
-1
-1
13.0
1
10
1
1
1
0
0
0
1
-16
16
-16
16
0
0
1
ticks
30.0

SWITCH
24
11
156
44
AllowDefer
AllowDefer
1
1
-1000

PLOT
4
298
204
448
Idle Books
ticks
idle
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot idlebooks"

BUTTON
52
59
126
92
Setup
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

BUTTON
8
107
71
140
Go
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
84
108
192
142
Single Tick
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

PLOT
5
146
205
296
Idle Patrons
ticks
idlepatrons
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot idlepatrons"

@#$#@#$#@
## WHAT IS IT?

This is a model of a library's waitlist for audio or electronic books. The library is only allowed to lend a book to one patron at a time. Thus, the other patrons that want to read that book must enter a wait list.

This model allows for **two policies**: 

1. **`AllowDefer` ON** - Patrons can "defer" a book they are loaned. By deferring a book, the patron keeps their position at the front of the waitlist, but allows the book to be offered to the next person in line. This can be a nice option when the patron already has enough books checked out to keep them occupied and are therefore unlikely to finish the newly offered book before the due date.

2. **`AllowDefer` OFF** - Without deferrment, the patron would have the book loaned to them but they would keep reading the current book(s) that they already checked out. Then the due date for the new book would arrive and the user would not be done. Thus they would have to request it again, and go to the end of the waitlist. This also has the disadvantage of depriving other patrons of reading the book while it sits idle in the busy patrons queue.

## HOW IT WORKS

The initial setup creates links between each book and each patron. These represent holds on the books. Each book creates an ordered waitlist from these holds. The books are grey to start.

On each tick, the books that are not on loan will offer themselves ot the next patron in their waitlist. Offered books are colored cyan. 

The patrons then add the offered books to their queue. Books in a queue are colored red.

If deferrment is allowed and the patron already has two books queued, then the patron will defer the book and not add it to their queue. Defered books are colored yellow.

Following the offers and deferments, each patron reads 20 pages of the first book in their queue. Books that are active (being read by a patron) are colored green. The idle books in their queues remain red in color.

When the current patron finishes the book they return it. The patron is removed from the book's waitlist, and the loan/hold link is removed from the model.

If the due date arrives and the current patron has not finished, the book is reclaimed and the patron is removed from the front of the waitlist and put back at the end of the waitlist. The progress is a property of the link, not the book, so when the book is reissued to the patron, they pick up right where they left off when it was reclaimed.

The plots for idles users and idle books are updated at this point. Idle Users are thos who have no books on loan even though they have one or more on hold. Idle books are those that are not actively being read even though they have one or more patrons in their waitlist.

The model stops running when all books have been read by all patrons (and thus all loan/hold links are removed).

## HOW TO USE IT

To run the model, simply click "Setup" and then click "Go". It is recommeded to run it at a slightly slower rate (~25% on the slider) to see the changes in the status of the books as they are offered, deferred, queued, and read. Alternatively, you can click on the "Single Tick" button instead of "Go" to slow it down even further.

The only input to the model is the switch for "AllowDefer". When this is on, patrons will defer an offered book if they already have two books on loan. If the switch is off, the user will add books to their queue no matter how many books are already on loan.

## THINGS TO NOTICE

Notice the ratio of green to red books. Green indicates active use, whereas red means the book is not being used even though there is someone who wants to read it.

Notice the plots for idle users and idle books and the shape of the graph over time for each of the policies.

Notice how many ticks it takes to complete the run of the model with each of the two policies. This indicates how long it takes for each reader to finish reading all 10 books.

## THINGS TO TRY

Run the model for both states of AllowDefer. You should see a lot more red with AllowDefer off and a lot more green with AllowDefer on.

## EXTENDING THE MODEL

There are many ways this model could be extended to make it more detailed, nuanced, or realistic.

- More books and users. This model only has 10 books and 10 patrons. Adding an input for each could improve the model for more dynamic investigations.

- Random initialization. This model sorts the patrons before creating the waitlists, making all waitlists the same. These could be randomized to reduce the numbmer of books initially offered to the first patron at the start of the model.

- Variable patron behaviors. To make it more realistic, the patron's behavior could be randomized. For instance, instead of reading 20 pages per day, it could be a rnadom number between 0 and 300. Or, instead of a purely random number, it could be influenced by a reading rate (some people read faster than others). This could then inform the size of the patron's queue. If they read faster they may be willing to take a third or fourth loan, whereas a slow reader may not even take a second loan. Also, some users like to read more then one book at a time. That is, they can read a few pages from the first book in their queue and a few pages from the second book, and so on.

- Turnover of population and inventory. To make it even more realistic the model could be extended to allow for an influx of new books and new patrons, as well as the weeding out of old books and the departure of patrons. 

- Popularity. Perhaps the most significant change that could be made to this model to make it more realistic would be to add a popularity property to the books. Books with a high popularity would be in demand and have larger waitlists than books with low popularity.

## NETLOGO FEATURES

This model makes use of `breeds`, which are custom agents. It has `patrons` and `books` which are custom turtles, and it also has `loans` which are custom links.

## RELATED MODELS


## CREDITS AND REFERENCES

Created by Joshua Nathan Gomez
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

book
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

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

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

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
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

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
