--  tdigest.ads
--
--  Dunning t-digest for online quantile estimation.
--  Merging digest variant with K_1 (arcsine) scale function.

package TDigest is

   --  ---------------------------------------------------------------
   --  Configuration constants
   --  ---------------------------------------------------------------
   Max_Centroids : constant := 1_000;
   Max_Buffer    : constant := 5_000;

   --  ---------------------------------------------------------------
   --  Types
   --  ---------------------------------------------------------------
   type Centroid is record
      Mean   : Long_Float := 0.0;
      Weight : Long_Float := 0.0;
   end record;

   type Centroid_Array is array (Positive range <>) of Centroid;

   --  Note: "delta" is a reserved word in Ada, so we use Compression.
   type T_Digest is record
      Centroids      : Centroid_Array (1 .. Max_Centroids);
      Num_Centroids  : Natural := 0;

      Buf            : Centroid_Array (1 .. Max_Buffer);
      Buf_Count      : Natural := 0;
      Buf_Cap        : Positive := Max_Buffer;

      Total_Weight   : Long_Float := 0.0;
      Min_Val        : Long_Float := Long_Float'Last;
      Max_Val        : Long_Float := Long_Float'First;
      Compression    : Long_Float := 100.0;
   end record;

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

end TDigest;
