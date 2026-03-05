use tdigest::TDigest;

fn main() {
    let mut td = TDigest::new(100.0);

    // Insert 10000 uniformly spaced values in [0, 1)
    let n = 10000;
    for i in 0..n {
        td.add(i as f64 / n as f64, 1.0);
    }

    println!("T-Digest demo: {} uniform values in [0, 1)", n);
    println!("Centroids: {}\n", td.centroid_count());

    println!("Quantile estimates (expected ~ q for uniform):");
    let quantiles = [0.001, 0.01, 0.1, 0.25, 0.5, 0.75, 0.9, 0.99, 0.999];
    for &q in &quantiles {
        let est = td.quantile(q).unwrap();
        println!(
            "  q={:<6.3}  estimated={:.6}  error={:.6}",
            q,
            est,
            (est - q).abs()
        );
    }

    println!("\nCDF estimates (expected ~ x for uniform):");
    for &x in &quantiles {
        let est = td.cdf(x).unwrap();
        println!(
            "  x={:<6.3}  estimated={:.6}  error={:.6}",
            x,
            est,
            (est - x).abs()
        );
    }

    // Test merge
    let mut td1 = TDigest::new(100.0);
    let mut td2 = TDigest::new(100.0);
    for i in 0..5000 {
        td1.add(i as f64 / 10000.0, 1.0);
    }
    for i in 5000..10000 {
        td2.add(i as f64 / 10000.0, 1.0);
    }
    td1.merge(&td2);

    println!("\nAfter merge:");
    println!(
        "  median={:.6} (expected ~0.5)",
        td1.quantile(0.5).unwrap()
    );
    println!(
        "  p99   ={:.6} (expected ~0.99)",
        td1.quantile(0.99).unwrap()
    );
}
