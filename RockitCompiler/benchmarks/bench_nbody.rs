// bench_nbody.rs — N-Body Simulation (CLBG)
// Single-threaded reference implementation

use std::f64::consts::PI;

const SOLAR_MASS: f64 = 4.0 * PI * PI;
const DAYS_PER_YEAR: f64 = 365.24;
const DT: f64 = 0.01;
const NBODIES: usize = 5;

struct Body {
    x: f64, y: f64, z: f64,
    vx: f64, vy: f64, vz: f64,
    mass: f64,
}

fn init_bodies() -> [Body; NBODIES] {
    [
        // Sun
        Body {
            x: 0.0, y: 0.0, z: 0.0,
            vx: 0.0, vy: 0.0, vz: 0.0,
            mass: SOLAR_MASS,
        },
        // Jupiter
        Body {
            x: 4.84143144246472090,
            y: -1.16032004402742839,
            z: -0.10362204447112311,
            vx: 0.00166007664274403694 * DAYS_PER_YEAR,
            vy: 0.00769901118419740425 * DAYS_PER_YEAR,
            vz: -0.0000690460016972063023 * DAYS_PER_YEAR,
            mass: 0.000954791938424326609 * SOLAR_MASS,
        },
        // Saturn
        Body {
            x: 8.34336671824457987,
            y: 4.12479856412430479,
            z: -0.403523417114321381,
            vx: -0.00276742510726862411 * DAYS_PER_YEAR,
            vy: 0.00499852801234917238 * DAYS_PER_YEAR,
            vz: 0.0000230417297573763929 * DAYS_PER_YEAR,
            mass: 0.000285885980666130812 * SOLAR_MASS,
        },
        // Uranus
        Body {
            x: 12.8943695621391310,
            y: -15.1111514016986312,
            z: -0.223307578892655734,
            vx: 0.00296460137564761618 * DAYS_PER_YEAR,
            vy: 0.00237847173959480950 * DAYS_PER_YEAR,
            vz: -0.0000296589568540237556 * DAYS_PER_YEAR,
            mass: 0.0000436624404335156298 * SOLAR_MASS,
        },
        // Neptune
        Body {
            x: 15.3796971148509165,
            y: -25.9193146099879641,
            z: 0.179258772950371181,
            vx: 0.00268067772490389322 * DAYS_PER_YEAR,
            vy: 0.00162824170038242295 * DAYS_PER_YEAR,
            vz: -0.0000951592254519715870 * DAYS_PER_YEAR,
            mass: 0.0000515138902046611451 * SOLAR_MASS,
        },
    ]
}

fn offset_momentum(bodies: &mut [Body; NBODIES]) {
    let mut px = 0.0_f64;
    let mut py = 0.0_f64;
    let mut pz = 0.0_f64;
    for i in 0..NBODIES {
        px += bodies[i].vx * bodies[i].mass;
        py += bodies[i].vy * bodies[i].mass;
        pz += bodies[i].vz * bodies[i].mass;
    }
    bodies[0].vx = -px / SOLAR_MASS;
    bodies[0].vy = -py / SOLAR_MASS;
    bodies[0].vz = -pz / SOLAR_MASS;
}

fn energy(bodies: &[Body; NBODIES]) -> f64 {
    let mut e = 0.0_f64;
    for i in 0..NBODIES {
        let bi = &bodies[i];
        e += 0.5 * bi.mass * (bi.vx * bi.vx + bi.vy * bi.vy + bi.vz * bi.vz);
        for j in (i + 1)..NBODIES {
            let bj = &bodies[j];
            let dx = bi.x - bj.x;
            let dy = bi.y - bj.y;
            let dz = bi.z - bj.z;
            let dist = (dx * dx + dy * dy + dz * dz).sqrt();
            e -= bi.mass * bj.mass / dist;
        }
    }
    e
}

fn advance(bodies: &mut [Body; NBODIES], dt: f64) {
    for i in 0..NBODIES {
        for j in (i + 1)..NBODIES {
            let dx = bodies[i].x - bodies[j].x;
            let dy = bodies[i].y - bodies[j].y;
            let dz = bodies[i].z - bodies[j].z;
            let d2 = dx * dx + dy * dy + dz * dz;
            let dist = d2.sqrt();
            let mag = dt / (d2 * dist);

            let mj = bodies[j].mass;
            let mi = bodies[i].mass;
            bodies[i].vx -= dx * mj * mag;
            bodies[i].vy -= dy * mj * mag;
            bodies[i].vz -= dz * mj * mag;
            bodies[j].vx += dx * mi * mag;
            bodies[j].vy += dy * mi * mag;
            bodies[j].vz += dz * mi * mag;
        }
    }
    for i in 0..NBODIES {
        bodies[i].x += dt * bodies[i].vx;
        bodies[i].y += dt * bodies[i].vy;
        bodies[i].z += dt * bodies[i].vz;
    }
}

fn main() {
    let n = 50000000;
    let mut bodies = init_bodies();
    offset_momentum(&mut bodies);

    println!("{:.9}", energy(&bodies));

    for _ in 0..n {
        advance(&mut bodies, DT);
    }

    println!("{:.9}", energy(&bodies));
}
