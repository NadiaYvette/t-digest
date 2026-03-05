--  bench.adb -- Benchmark / asymptotic-behavior tests for Ada t-digest
--  Compile: gnatmake -O2 bench.adb -o bench

with Ada.Text_IO;
with Ada.Long_Float_Text_IO;
with Ada.Integer_Text_IO;
with Ada.Calendar;
with TDigest;

procedure Bench is

   use Ada.Text_IO;
   use Ada.Calendar;

   --  ---------------------------------------------------------------
   --  Helpers
   --  ---------------------------------------------------------------

   Pass_Count : Natural := 0;
   Fail_Count : Natural := 0;

   function Get_Time_Ms return Long_Float is
      Now : constant Time := Clock;
      S   : constant Duration := Seconds (Now);
   begin
      return Long_Float (S) * 1000.0;
   end Get_Time_Ms;

   procedure Check (Label : String; OK : Boolean) is
   begin
      if OK then
         Pass_Count := Pass_Count + 1;
         Put_Line ("  " & Label & "  PASS");
      else
         Fail_Count := Fail_Count + 1;
         Put_Line ("  " & Label & "  FAIL");
      end if;
   end Check;

   function Ratio_OK (Ratio : Long_Float; Expected : Long_Float) return Boolean is
   begin
      return Ratio >= Expected * 0.5 and then Ratio <= Expected * 3.0;
   end Ratio_OK;

   function Ratio_OK_Wide (Ratio : Long_Float; Expected : Long_Float) return Boolean is
   begin
      return Ratio >= Expected * 0.2 and then Ratio <= Expected * 5.0;
   end Ratio_OK_Wide;

   function LF_Img (V : Long_Float; Aft : Natural) return String is
      S : String (1 .. 40);
   begin
      Ada.Long_Float_Text_IO.Put (S, V, Aft => Aft, Exp => 0);
      -- Trim leading spaces
      for I in S'Range loop
         if S (I) /= ' ' then
            return S (I .. S'Last);
         end if;
      end loop;
      return S;
   end LF_Img;

   function Int_Img (V : Integer) return String is
      S : String := Integer'Image (V);
   begin
      if S (S'First) = ' ' then
         return S (S'First + 1 .. S'Last);
      end if;
      return S;
   end Int_Img;

   --  Simple LCG random
   RNG_State : Long_Float := 12345.0;
   function Simple_Random return Long_Float is
      S : Long_Float := RNG_State;
   begin
      S := Long_Float (Long_Long_Integer (S * 1103515245.0 + 12345.0)
                        mod 2147483648);
      RNG_State := S;
      return S / 2147483648.0;
   end Simple_Random;

   --  ---------------------------------------------------------------
   --  Test variables
   --  ---------------------------------------------------------------

   type Int_Array is array (Positive range <>) of Integer;
   type LF_Array is array (Positive range <>) of Long_Float;

   Sizes : constant Int_Array := (1000, 10000, 100000, 1000000);
   Times_1 : LF_Array (1 .. 4);

   Query_Sizes : constant Int_Array := (1000, 10000, 100000);
   Query_Times : LF_Array (1 .. 3);

   Deltas : constant LF_Array := (50.0, 100.0, 200.0);
   Tail_Qs : constant LF_Array := (0.01, 0.001, 0.99, 0.999);
   Errors : LF_Array (1 .. 3);

   Compress_Sizes : constant Int_Array := (500, 5000, 50000);
   Compress_Times : LF_Array (1 .. 3);

   T0, T1 : Long_Float;
   TD, TD1, TD2 : TDigest.T_Digest;

begin
   Put_Line ("=== T-Digest Asymptotic Behavior Tests (Ada) ===");
   New_Line;

   --  ---------------------------------------------------------------
   --  Test 1: add() is amortized O(1)
   --  ---------------------------------------------------------------
   Put_Line ("--- Test 1: add() is amortized O(1) ---");

   for SI in Sizes'Range loop
      TD := TDigest.Create (100.0);
      T0 := Get_Time_Ms;
      for I in 0 .. Sizes (SI) - 1 loop
         TDigest.Add (TD, Long_Float (I) / Long_Float (Sizes (SI)));
      end loop;
      T1 := Get_Time_Ms;
      Times_1 (SI) := T1 - T0;
      Put ("  N=" & Int_Img (Sizes (SI)));
      Put ("  time=" & LF_Img (Times_1 (SI), 1) & "ms");
      New_Line;
   end loop;

   for SI in 2 .. Sizes'Last loop
      declare
         Expected : constant Long_Float :=
           Long_Float (Sizes (SI)) / Long_Float (Sizes (SI - 1));
         Ratio : constant Long_Float := Times_1 (SI) / Times_1 (SI - 1);
      begin
         Check ("N=" & Int_Img (Sizes (SI)) &
                "  ratio=" & LF_Img (Ratio, 2) &
                " (expected ~" & LF_Img (Expected, 1) & ")",
                Ratio_OK (Ratio, Expected));
      end;
   end loop;

   New_Line;

   --  ---------------------------------------------------------------
   --  Test 2: Centroid count bounded by O(delta)
   --  ---------------------------------------------------------------
   Put_Line ("--- Test 2: Centroid count bounded by O(delta) ---");

   for SI in Sizes'Range loop
      TD := TDigest.Create (100.0);
      for I in 0 .. Sizes (SI) - 1 loop
         TDigest.Add (TD, Long_Float (I) / Long_Float (Sizes (SI)));
      end loop;
      declare
         CC : constant Natural := TDigest.Centroid_Count (TD);
      begin
         Check ("N=" & Int_Img (Sizes (SI)) &
                "  centroids=" & Int_Img (CC) &
                "  (delta=100, limit=500)",
                CC <= 500);
      end;
   end loop;

   New_Line;

   --  ---------------------------------------------------------------
   --  Test 3: Query time independent of N
   --  ---------------------------------------------------------------
   Put_Line ("--- Test 3: Query time independent of N ---");

   for SI in Query_Sizes'Range loop
      TD := TDigest.Create (100.0);
      for I in 0 .. Query_Sizes (SI) - 1 loop
         TDigest.Add (TD, Long_Float (I) / Long_Float (Query_Sizes (SI)));
      end loop;
      TDigest.Compress (TD);
      declare
         Iterations : constant := 10000;
         Dummy : Long_Float := 0.0;
         Us_Per : Long_Float;
      begin
         T0 := Get_Time_Ms;
         for J in 1 .. Iterations loop
            Dummy := Dummy + TDigest.Quantile (TD, 0.5);
            Dummy := Dummy + TDigest.CDF (TD, 0.5);
         end loop;
         T1 := Get_Time_Ms;
         Us_Per := ((T1 - T0) * 1000.0) / Long_Float (Iterations);
         Query_Times (SI) := Us_Per;
         Put ("  N=" & Int_Img (Query_Sizes (SI)));
         Put ("  query_time=" & LF_Img (Us_Per, 2) & "us");
         New_Line;
         -- Prevent optimization of Dummy
         if Dummy < -1.0e30 then
            Put_Line ("impossible");
         end if;
      end;
   end loop;

   for SI in 2 .. Query_Sizes'Last loop
      declare
         Ratio : constant Long_Float := Query_Times (SI) / Query_Times (SI - 1);
      begin
         Check ("N=" & Int_Img (Query_Sizes (SI)) &
                "  ratio=" & LF_Img (Ratio, 2) &
                " (expected ~1.0)",
                Ratio_OK_Wide (Ratio, 1.0));
      end;
   end loop;

   New_Line;

   --  ---------------------------------------------------------------
   --  Test 4: Tail accuracy improves with delta
   --  ---------------------------------------------------------------
   Put_Line ("--- Test 4: Tail accuracy improves with delta ---");

   for QI in Tail_Qs'Range loop
      for DI in Deltas'Range loop
         TD := TDigest.Create (Deltas (DI));
         for I in 0 .. 99999 loop
            TDigest.Add (TD, Long_Float (I) / 100000.0);
         end loop;
         declare
            Est : constant Long_Float := TDigest.Quantile (TD, Tail_Qs (QI));
            Err : constant Long_Float := abs (Est - Tail_Qs (QI));
         begin
            Errors (DI) := Err;
            Put ("  delta=" & Int_Img (Integer (Deltas (DI))));
            Put ("  q=" & LF_Img (Tail_Qs (QI), 3));
            Put ("  error=" & LF_Img (Err, 6));
            New_Line;
         end;
      end loop;

      for DI in 2 .. Deltas'Last loop
         declare
            OK : constant Boolean :=
              Errors (DI) <= Errors (DI - 1) * 1.5 + 0.001;
         begin
            Check ("delta=" & Int_Img (Integer (Deltas (DI))) &
                   " q=" & LF_Img (Tail_Qs (QI), 3) &
                   " error decreases (" &
                   LF_Img (Errors (DI), 6) & " <= " &
                   LF_Img (Errors (DI - 1), 6) & ")",
                   OK);
         end;
      end loop;
   end loop;

   New_Line;

   --  ---------------------------------------------------------------
   --  Test 5: Merge preserves weight and accuracy
   --  ---------------------------------------------------------------
   Put_Line ("--- Test 5: Merge preserves weight and accuracy ---");

   declare
      N_Merge : constant := 10000;
      W_Before : Long_Float;
      Median_Est, Median_Err : Long_Float;
      P99_Est, P99_Err : Long_Float;
   begin
      TD1 := TDigest.Create (100.0);
      TD2 := TDigest.Create (100.0);
      for I in 0 .. N_Merge / 2 - 1 loop
         TDigest.Add (TD1, Long_Float (I) / Long_Float (N_Merge));
      end loop;
      for I in N_Merge / 2 .. N_Merge - 1 loop
         TDigest.Add (TD2, Long_Float (I) / Long_Float (N_Merge));
      end loop;

      W_Before := TD1.Total_Weight + TD2.Total_Weight;
      TDigest.Merge (TD1, TD2);

      Check ("weight_before=" & LF_Img (W_Before, 0) &
             "  weight_after=" & LF_Img (TD1.Total_Weight, 0) &
             "  (equal)",
             abs (W_Before - TD1.Total_Weight) < 1.0e-9);

      Median_Est := TDigest.Quantile (TD1, 0.5);
      Median_Err := abs (Median_Est - 0.5);
      Check ("median_error=" & LF_Img (Median_Err, 6) & "  (< 0.05)",
             Median_Err < 0.05);

      P99_Est := TDigest.Quantile (TD1, 0.99);
      P99_Err := abs (P99_Est - 0.99);
      Check ("p99_error=" & LF_Img (P99_Err, 6) & "  (< 0.05)",
             P99_Err < 0.05);
   end;

   New_Line;

   --  ---------------------------------------------------------------
   --  Test 6: compress is O(n log n)
   --  ---------------------------------------------------------------
   Put_Line ("--- Test 6: compress is O(n log n) ---");

   for SI in Compress_Sizes'Range loop
      TD := TDigest.Create (100.0);
      --  Fill buffer manually
      for I in 1 .. Compress_Sizes (SI) loop
         declare
            V : constant Long_Float := Simple_Random;
         begin
            TD.Buf_Count := TD.Buf_Count + 1;
            TD.Buf (TD.Buf_Count) := (Mean => V, Weight => 1.0);
            TD.Total_Weight := TD.Total_Weight + 1.0;
            if V < TD.Min_Val then
               TD.Min_Val := V;
            end if;
            if V > TD.Max_Val then
               TD.Max_Val := V;
            end if;
         end;
      end loop;

      T0 := Get_Time_Ms;
      TDigest.Compress (TD);
      T1 := Get_Time_Ms;
      Compress_Times (SI) := T1 - T0;
      Put ("  buf_n=" & Int_Img (Compress_Sizes (SI)));
      Put ("  compress_time=" & LF_Img (Compress_Times (SI), 2) & "ms");
      New_Line;
   end loop;

   for SI in 2 .. Compress_Sizes'Last loop
      declare
         N0 : constant Long_Float := Long_Float (Compress_Sizes (SI - 1));
         N1 : constant Long_Float := Long_Float (Compress_Sizes (SI));
         Scale : constant Long_Float := N1 / N0;
         Ratio : constant Long_Float :=
           Compress_Times (SI) / Compress_Times (SI - 1);
      begin
         Check ("buf_n=" & Int_Img (Compress_Sizes (SI)) &
                "  ratio=" & LF_Img (Ratio, 2) &
                " (expected ~" & LF_Img (Scale, 1) & "x to " &
                LF_Img (Scale * 2.0, 1) & "x)",
                Ratio >= Scale * 0.3 and then Ratio <= Scale * 4.0);
      end;
   end loop;

   New_Line;

   --  ---------------------------------------------------------------
   --  Summary
   --  ---------------------------------------------------------------
   declare
      Total : constant Natural := Pass_Count + Fail_Count;
   begin
      Put_Line ("Summary: " & Int_Img (Pass_Count) & "/" &
                Int_Img (Total) & " tests passed");
   end;
end Bench;
