--  tdigest.ads
--
--  Dunning t-digest for online quantile estimation.
--  Merging digest variant with K_1 (arcsine) scale function.
--  Uses an array-backed 2-3-4 tree with four-component monoidal measures.

with Tree234;

package TDigest is

   --  ---------------------------------------------------------------
   --  Configuration constants
   --  ---------------------------------------------------------------
   Max_Buffer : constant := 5_000;

   --  ---------------------------------------------------------------
   --  Types
   --  ---------------------------------------------------------------
   type Centroid is record
      Mean   : Long_Float := 0.0;
      Weight : Long_Float := 0.0;
   end record;

   type Centroid_Array is array (Positive range <>) of Centroid;

   --  Four-component monoidal measure for the 2-3-4 tree
   type Td_Measure is record
      Weight          : Long_Float := 0.0;
      Count           : Natural := 0;
      Max_Mean        : Long_Float := Long_Float'First;
      Mean_Weight_Sum : Long_Float := 0.0;
   end record;

   --  Note: "delta" is a reserved word in Ada, so we use Compression.
   type T_Digest is private;

   --  ---------------------------------------------------------------
   --  Public operations
   --  ---------------------------------------------------------------

   --  Create a fresh t-digest with the given compression parameter.
   function Create (Compression : Long_Float := 100.0) return T_Digest;

   --  Add a single weighted value to the digest.
   procedure Add (TD     : in out T_Digest;
                  Value  : Long_Float;
                  Weight : Long_Float := 1.0);

   --  Force compression of all buffered values into centroids.
   procedure Compress (TD : in out T_Digest);

   --  Return the estimated quantile (0.0 .. 1.0) value.
   function Quantile (TD : in out T_Digest;
                      Q  : Long_Float) return Long_Float;

   --  Return the estimated CDF value at X.
   function CDF (TD : in out T_Digest;
                 X  : Long_Float) return Long_Float;

   --  Merge another digest into TD (TD absorbs all of Other's data).
   procedure Merge (TD    : in out T_Digest;
                    Other : in out T_Digest);

   --  Number of merged centroids (flushes buffer first).
   function Centroid_Count (TD : in out T_Digest) return Natural;

private

   --  Measure operations (used as generic formals for Tree234)
   function Measure_One (C : Centroid) return Td_Measure;
   function Combine_Measures (A, B : Td_Measure) return Td_Measure;
   function Identity_Measure return Td_Measure;
   function Compare_Centroids (A, B : Centroid) return Integer;
   function Measure_Weight (M : Td_Measure) return Long_Float;

   --  Instantiate the generic 2-3-4 tree with centroid keys and measures
   package Centroid_Tree is new Tree234
     (Key_Type     => Centroid,
      Measure_Type => Td_Measure,
      Measure_One  => Measure_One,
      Combine      => Combine_Measures,
      Identity     => Identity_Measure,
      Compare      => Compare_Centroids,
      Weight_Of    => Measure_Weight);

   --  Use with clause removed to avoid circular dependency issues.
   --  We will use fully-qualified names in the body.

   type T_Digest is record
      Tree_Data      : Centroid_Tree.Tree;

      Buf            : Centroid_Array (1 .. Max_Buffer);
      Buf_Count      : Natural := 0;
      Buf_Cap        : Positive := Max_Buffer;

      Total_Weight   : Long_Float := 0.0;
      Min_Val        : Long_Float := Long_Float'Last;
      Max_Val        : Long_Float := Long_Float'First;
      Compression    : Long_Float := 100.0;
   end record;

end TDigest;
