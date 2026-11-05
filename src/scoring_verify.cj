package orz_mania

// Hand-calculated ScoreV1 references, plus input-driven judgement boundary checks.
func scoringFixture(): Chart { parseChart(SCORE_TEST_MAP,"Songs/scoring/map.osu") }
func holdFixture(): Play {
    let c=Chart(); c.keys=4; c.od=5.0; c.notes.add(Note(0,1000,3000)); c.duration=3000
    Play(c)
}
func verifyScoring(): Unit {
    let big=Play(scoringFixture()); let small=Play(scoringFixture())
    for (_ in 0..3) { big.award(0,0); small.award(1,0) }
    require(big.score == 1000000 && small.score == 968750 && big.accuracy() == 10000 && small.accuracy() == 10000,"Big/small P both give full accuracy, with different scores")
    let c=Chart(); for (i in 0..6) { c.notes.add(Note(0,i*1000,i*1000)) }
    let mixed=Play(c)
    for (g in 0..6) { mixed.award(g,0) }
    require(mixed.score == 481519 && mixed.accuracy() == 5277 && mixed.bonus == 0,"Mixed six-judgement reference: updated bonus, accumulated score rounding and separate accuracy")
    let recovery=Chart(); for (i in 0..102) { recovery.notes.add(Note(0,i*1000,i*1000)) }
    let reset=Play(recovery); reset.award(5,0); reset.award(0,1)
    require(reset.bonus == 2,"Bonus resets on MISS and recovers with the next judgement")
    for (_ in 0..100) { reset.award(0,2) }
    require(reset.bonus == 100,"Bonus recovery is bounded")
    for (od in [0.0,5.0,10.0]) {
        let chart=scoringFixture(); chart.od=od; let p=Play(chart)
        for (g in 0..5) {
            require(p.grade(p.windows[g]) == g && p.grade(-p.windows[g]) == g,"Inclusive symmetric grade thresholds")
            require(p.grade(p.windows[g]+1) == g+1,"Next grade starts outside the threshold")
        }
    }
    let ignore=Play(scoringFixture()); ignore.press(0,826)
    require(ignore.judged == 0,"Input before the early MISS window is ignored")
    let earlyMiss=Play(scoringFixture()); earlyMiss.press(0,827)
    require(earlyMiss.counts[5] == 1,"Input inside early MISS but outside MEH consumes the note as MISS")
    let earlyMeh=Play(scoringFixture()); earlyMeh.press(0,864)
    require(earlyMeh.counts[4] == 1,"Early MEH boundary is 151 minus 3 OD")
    let late=Play(scoringFixture()); late.press(0,1112)
    require(late.counts[3] == 1,"Late OK boundary remains hittable")
    let expired=Play(scoringFixture()); expired.press(0,1113)
    require(expired.counts[5] == 1 && expired.judged == 1,"Late MEH cannot be hit even before the next update")
    // Use a separate chronological same-lane pair to test early notelock.
    let pair=Chart(); pair.notes.add(Note(0,1000,1000)); pair.notes.add(Note(0,1100,1100))
    let lock=Play(pair); lock.press(0,1090)
    require(pair.notes[0].state == 2 && pair.notes[1].state == 0 && lock.counts[3] == 1,"First pending note retains same-lane priority")
    let exact=holdFixture(); exact.press(0,1000); exact.release(0,3000)
    require(exact.counts[0] == 1 && exact.judged == 1,"Hold head and tail produce one combined judgement")
    let lenient=holdFixture(); lenient.press(0,1019); lenient.release(0,2981)
    require(lenient.counts[0] == 1,"Hold PERFECT head 1.2x and combined 2.4x lenience")
    let tail=holdFixture(); tail.press(0,1000); tail.release(0,2961)
    require(tail.counts[1] == 1,"Tail timing affects the final judgement")
    let dropped=holdFixture(); dropped.press(0,1000); dropped.release(0,2500)
    dropped.press(0,2900); dropped.release(0,3000)
    require(dropped.counts[4] == 1,"Re-grabbing a broken hold is capped at MEH")
    let missed=holdFixture(); missed.press(0,1000); missed.release(0,2500); missed.update(3113,false)
    require(missed.counts[5] == 1,"Unrecovered early release expires as MISS")
    let held=holdFixture(); held.press(0,1000); held.update(3113,false); held.update(5000,false)
    require(held.judged == 1 && held.counts[2] == 1,"Held tail resolves once at late OK with combined timing")
    println("PASS ScoreV1: big/small P accuracy / 968750 reference / mixed 481519 / bonus recovery / OD boundaries / early MISS / no late MEH / notelock / combined hold judgement / dropped hold recovery")
}
