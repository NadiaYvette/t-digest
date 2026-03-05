// Demo for t-digest C# implementation.

using System;
using TDigestLib;

class Demo
{
    static void Main()
    {
        int n = 10000;
        var td = new TDigest(100);

        for (int i = 0; i < n; i++)
        {
            td.Add((double)i / n);
        }

        Console.WriteLine($"T-Digest demo: {n} uniform values in [0, 1)");
        Console.WriteLine($"Centroids: {td.CentroidCount}");
        Console.WriteLine();
        Console.WriteLine("Quantile estimates (expected ~ q for uniform):");

        double[] testPoints = { 0.001, 0.01, 0.1, 0.25, 0.5, 0.75, 0.9, 0.99, 0.999 };

        foreach (double q in testPoints)
        {
            double est = td.Quantile(q).Value;
            double error = Math.Abs(est - q);
            Console.WriteLine($"  q={q,-6:F3}  estimated={est:F6}  error={error:F6}");
        }

        Console.WriteLine();
        Console.WriteLine("CDF estimates (expected ~ x for uniform):");

        foreach (double x in testPoints)
        {
            double est = td.Cdf(x).Value;
            double error = Math.Abs(est - x);
            Console.WriteLine($"  x={x,-6:F3}  estimated={est:F6}  error={error:F6}");
        }

        // Test merge
        var td1 = new TDigest(100);
        var td2 = new TDigest(100);
        for (int i = 0; i < 5000; i++) td1.Add((double)i / 10000);
        for (int i = 5000; i < 10000; i++) td2.Add((double)i / 10000);
        td1.Merge(td2);

        Console.WriteLine();
        Console.WriteLine("After merge:");
        Console.WriteLine($"  median={td1.Quantile(0.5).Value:F6} (expected ~0.5)");
        Console.WriteLine($"  p99   ={td1.Quantile(0.99).Value:F6} (expected ~0.99)");
    }
}
