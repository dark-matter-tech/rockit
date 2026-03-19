// bench_nbody.js — N-Body Simulation (CLBG)
// Single-threaded reference implementation

const PI = 3.141592653589793;
const SOLAR_MASS = 4.0 * PI * PI;
const DAYS_PER_YEAR = 365.24;
const DT = 0.01;
const NBODIES = 5;

function initBodies() {
    return [
        // Sun
        { x: 0, y: 0, z: 0, vx: 0, vy: 0, vz: 0, mass: SOLAR_MASS },
        // Jupiter
        {
            x: 4.84143144246472090,
            y: -1.16032004402742839,
            z: -0.10362204447112311,
            vx: 0.00166007664274403694 * DAYS_PER_YEAR,
            vy: 0.00769901118419740425 * DAYS_PER_YEAR,
            vz: -0.0000690460016972063023 * DAYS_PER_YEAR,
            mass: 0.000954791938424326609 * SOLAR_MASS,
        },
        // Saturn
        {
            x: 8.34336671824457987,
            y: 4.12479856412430479,
            z: -0.403523417114321381,
            vx: -0.00276742510726862411 * DAYS_PER_YEAR,
            vy: 0.00499852801234917238 * DAYS_PER_YEAR,
            vz: 0.0000230417297573763929 * DAYS_PER_YEAR,
            mass: 0.000285885980666130812 * SOLAR_MASS,
        },
        // Uranus
        {
            x: 12.8943695621391310,
            y: -15.1111514016986312,
            z: -0.223307578892655734,
            vx: 0.00296460137564761618 * DAYS_PER_YEAR,
            vy: 0.00237847173959480950 * DAYS_PER_YEAR,
            vz: -0.0000296589568540237556 * DAYS_PER_YEAR,
            mass: 0.0000436624404335156298 * SOLAR_MASS,
        },
        // Neptune
        {
            x: 15.3796971148509165,
            y: -25.9193146099879641,
            z: 0.179258772950371181,
            vx: 0.00268067772490389322 * DAYS_PER_YEAR,
            vy: 0.00162824170038242295 * DAYS_PER_YEAR,
            vz: -0.0000951592254519715870 * DAYS_PER_YEAR,
            mass: 0.0000515138902046611451 * SOLAR_MASS,
        },
    ];
}

function offsetMomentum(bodies) {
    let px = 0, py = 0, pz = 0;
    for (let i = 0; i < NBODIES; i++) {
        px += bodies[i].vx * bodies[i].mass;
        py += bodies[i].vy * bodies[i].mass;
        pz += bodies[i].vz * bodies[i].mass;
    }
    bodies[0].vx = -px / SOLAR_MASS;
    bodies[0].vy = -py / SOLAR_MASS;
    bodies[0].vz = -pz / SOLAR_MASS;
}

function energy(bodies) {
    let e = 0;
    for (let i = 0; i < NBODIES; i++) {
        const bi = bodies[i];
        e += 0.5 * bi.mass * (bi.vx * bi.vx + bi.vy * bi.vy + bi.vz * bi.vz);
        for (let j = i + 1; j < NBODIES; j++) {
            const bj = bodies[j];
            const dx = bi.x - bj.x;
            const dy = bi.y - bj.y;
            const dz = bi.z - bj.z;
            const dist = Math.sqrt(dx * dx + dy * dy + dz * dz);
            e -= bi.mass * bj.mass / dist;
        }
    }
    return e;
}

function advance(bodies, dt) {
    for (let i = 0; i < NBODIES; i++) {
        const bi = bodies[i];
        for (let j = i + 1; j < NBODIES; j++) {
            const bj = bodies[j];
            const dx = bi.x - bj.x;
            const dy = bi.y - bj.y;
            const dz = bi.z - bj.z;
            const d2 = dx * dx + dy * dy + dz * dz;
            const dist = Math.sqrt(d2);
            const mag = dt / (d2 * dist);

            bi.vx -= dx * bj.mass * mag;
            bi.vy -= dy * bj.mass * mag;
            bi.vz -= dz * bj.mass * mag;
            bj.vx += dx * bi.mass * mag;
            bj.vy += dy * bi.mass * mag;
            bj.vz += dz * bi.mass * mag;
        }
    }
    for (let i = 0; i < NBODIES; i++) {
        const bi = bodies[i];
        bi.x += dt * bi.vx;
        bi.y += dt * bi.vy;
        bi.z += dt * bi.vz;
    }
}

function main() {
    const n = 50000000;
    const bodies = initBodies();
    offsetMomentum(bodies);

    console.log(energy(bodies).toFixed(9));

    for (let i = 0; i < n; i++) {
        advance(bodies, DT);
    }

    console.log(energy(bodies).toFixed(9));
}

main();
