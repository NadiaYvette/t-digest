--  demo.adb
--
--  Demonstration / self-test for the TDigest package.
--  Compile:  gnatmake demo.adb

with Ada.Text_IO;
with Ada.Long_Float_Text_IO;
with TDigest;

procedure Demo is

   use Ada.Text_IO;
   use Ada.Long_Float_Text_IO;
   use TDigest;

   N : constant := 10_000;

   TD  : T_Digest := Create (100.0);
   TD1 : T_Digest := Create (100.0);
   TD2 : T_Digest := Create (100.0);

   type LF_Array is array (Positive range <>) of Long_Float;

   Test_Points : constant LF_Array :=
     (0.001, 0.01, 0.1, 0.25, 0.5, 0.75, 0.9, 0.99, 0.999);

   Est : Long_Float;
   Err : Long_Float;

begin
   --  Insert 10 000 uniformly-spaced values in [0, 1).
   for I in 0 .. N - 1 loop
      Add (TD, Long_Float (I) / Long_Float (N));
   end loop;

   Put_Line ("T-Digest demo:" & Natural'Image (N)
             & " uniform values in [0, 1)");
   Put ("Centroids:");
   Put_Line (Natural'Image (Centroid_Count (TD)));
   New_Line;

   --  Quantile estimates.
   Put_Line ("Quantile estimates (expected ~ q for uniform):");
   for J in Test_Points'Range loop
      Est := Quantile (TD, Test_Points (J));
      Err := abs (Est - Test_Points (J));
      Put ("  q=");
      Put (Test_Points (J), Fore => 1, Aft => 3, Exp => 0);
      Put ("  estimated=");
      Put (Est, Fore => 1, Aft => 6, Exp => 0);
      Put ("  error=");
      Put (Err, Fore => 1, Aft => 6, Exp => 0);
      New_Line;
   end loop;

   New_Line;

   --  CDF estimates.
   Put_Line ("CDF estimates (expected ~ x for uniform):");
   for J in Test_Points'Range loop
      Est := CDF (TD, Test_Points (J));
      Err := abs (Est - Test_Points (J));
      Put ("  x=");
      Put (Test_Points (J), Fore => 1, Aft => 3, Exp => 0);
      Put ("  estimated=");
      Put (Est, Fore => 1, Aft => 6, Exp => 0);
      Put ("  error=");
      Put (Err, Fore => 1, Aft => 6, Exp => 0);
      New_Line;
   end loop;

   New_Line;

   --  Test merge: split data into two halves, merge, and check.
   for I in 0 .. 4999 loop
      Add (TD1, Long_Float (I) / Long_Float (N));
   end loop;
   for I in 5000 .. 9999 loop
      Add (TD2, Long_Float (I) / Long_Float (N));
   end loop;
   Merge (TD1, TD2);

   Put_Line ("After merge:");
   Put ("  median=");
   Put (Quantile (TD1, 0.5), Fore => 1, Aft => 6, Exp => 0);
   Put_Line (" (expected ~0.5)");
   Put ("  p99   =");
   Put (Quantile (TD1, 0.99), Fore => 1, Aft => 6, Exp => 0);
   Put_Line (" (expected ~0.99)");
end Demo;
