// bench_nbody.go — N-Body Simulation (CLBG)
// Single-threaded reference implementation
package main

import (
	"fmt"
	"math"
)

const (
	PI           = 3.141592653589793
	SOLAR_MASS   = 4.0 * PI * PI
	DAYS_PER_YEAR = 365.24
	DT           = 0.01
	NBODIES      = 5
)

type Body struct {
	x, y, z    float64
	vx, vy, vz float64
	mass       float64
}

func initBodies() [NBODIES]Body {
	return [NBODIES]Body{
		// Sun
		{0, 0, 0, 0, 0, 0, SOLAR_MASS},
		// Jupiter
		{
			4.84143144246472090,
			-1.16032004402742839,
			-0.10362204447112311,
			0.00166007664274403694 * DAYS_PER_YEAR,
			0.00769901118419740425 * DAYS_PER_YEAR,
			-0.0000690460016972063023 * DAYS_PER_YEAR,
			0.000954791938424326609 * SOLAR_MASS,
		},
		// Saturn
		{
			8.34336671824457987,
			4.12479856412430479,
			-0.403523417114321381,
			-0.00276742510726862411 * DAYS_PER_YEAR,
			0.00499852801234917238 * DAYS_PER_YEAR,
			0.0000230417297573763929 * DAYS_PER_YEAR,
			0.000285885980666130812 * SOLAR_MASS,
		},
		// Uranus
		{
			12.8943695621391310,
			-15.1111514016986312,
			-0.223307578892655734,
			0.00296460137564761618 * DAYS_PER_YEAR,
			0.00237847173959480950 * DAYS_PER_YEAR,
			-0.0000296589568540237556 * DAYS_PER_YEAR,
			0.0000436624404335156298 * SOLAR_MASS,
		},
		// Neptune
		{
			15.3796971148509165,
			-25.9193146099879641,
			0.179258772950371181,
			0.00268067772490389322 * DAYS_PER_YEAR,
			0.00162824170038242295 * DAYS_PER_YEAR,
			-0.0000951592254519715870 * DAYS_PER_YEAR,
			0.0000515138902046611451 * SOLAR_MASS,
		},
	}
}

func offsetMomentum(bodies *[NBODIES]Body) {
	var px, py, pz float64
	for i := 0; i < NBODIES; i++ {
		px += bodies[i].vx * bodies[i].mass
		py += bodies[i].vy * bodies[i].mass
		pz += bodies[i].vz * bodies[i].mass
	}
	bodies[0].vx = -px / SOLAR_MASS
	bodies[0].vy = -py / SOLAR_MASS
	bodies[0].vz = -pz / SOLAR_MASS
}

func energy(bodies *[NBODIES]Body) float64 {
	e := 0.0
	for i := 0; i < NBODIES; i++ {
		bi := &bodies[i]
		e += 0.5 * bi.mass * (bi.vx*bi.vx + bi.vy*bi.vy + bi.vz*bi.vz)
		for j := i + 1; j < NBODIES; j++ {
			bj := &bodies[j]
			dx := bi.x - bj.x
			dy := bi.y - bj.y
			dz := bi.z - bj.z
			dist := math.Sqrt(dx*dx + dy*dy + dz*dz)
			e -= bi.mass * bj.mass / dist
		}
	}
	return e
}

func advance(bodies *[NBODIES]Body, dt float64) {
	for i := 0; i < NBODIES; i++ {
		bi := &bodies[i]
		for j := i + 1; j < NBODIES; j++ {
			bj := &bodies[j]
			dx := bi.x - bj.x
			dy := bi.y - bj.y
			dz := bi.z - bj.z
			d2 := dx*dx + dy*dy + dz*dz
			dist := math.Sqrt(d2)
			mag := dt / (d2 * dist)

			bi.vx -= dx * bj.mass * mag
			bi.vy -= dy * bj.mass * mag
			bi.vz -= dz * bj.mass * mag
			bj.vx += dx * bi.mass * mag
			bj.vy += dy * bi.mass * mag
			bj.vz += dz * bi.mass * mag
		}
	}
	for i := 0; i < NBODIES; i++ {
		bi := &bodies[i]
		bi.x += dt * bi.vx
		bi.y += dt * bi.vy
		bi.z += dt * bi.vz
	}
}

func main() {
	n := 50000000
	bodies := initBodies()
	offsetMomentum(&bodies)

	fmt.Printf("%0.9f\n", energy(&bodies))

	for i := 0; i < n; i++ {
		advance(&bodies, DT)
	}

	fmt.Printf("%0.9f\n", energy(&bodies))
}
