// Buddhabrot - Draws the fractal of Buddhabrot in the Odin progamming language.
// Author:  Joao Nuno Carvalho
// Date:    2023.09.16
// License: MIT OpenSource License
//
// Description: Draws the Buddhabrot Set.
//              Port in Odin from my port to Go and to Ptyhon based on the C code found on
//              http://paulbourke.net/fractals/buddhabrot/buddha.c
//              See also:
//              http://paulbourke.net/fractals/buddhabrot/
//              https://en.wikipedia.org/wiki/Buddhabrot#Relation_to_the_logistic_map
//
//              https://github.com/joaocarvalhoopen/Fractal_Buddhabrot
//

package main

import "core:fmt"
import "core:math"
import "core:math/bits"
import "core:math/rand"
import "core:bytes"

// note two imports, one for image utils (compute_buffer_size) and tga
import "core:image"
import "core:image/tga"

// Image size.
C_NX : i32 : 1000
C_NY : i32 : 1000
// Lenght of the sequence to test escape status.
// Also known as bailout
C_NMAX : i32 : 200

// Number of iterations, multiple of 1 million.
C_TMAX : i32 : 1000 //100 // 2000 // 1000 // 100

// Name of the output file.
// C_FILENAME : string : "buddhabrot_single_1000.png"
C_FILENAME : string : "./buddhabrot_single_1000.tga"

main :: proc () {

	fmt.printf("Starting fractal_buddhabrot.odin....\n")

	buddhabrot( C_FILENAME, C_NX, C_NY, C_NMAX, C_TMAX )

	fmt.printf("...ending fractal_buddhabrot.odin .")

}

buddhabrot :: proc ( filename : string, nx : i32, ny : i32, nmax : i32, tmax : i32 ) {
	image_out := [ C_NX ][ C_NY ]f64{ }

	xy_seq_x := [ C_NMAX ]f64{}
	xy_seq_y := [ C_NMAX ]f64{}

	n : i32 = 0

	C_NX_2 : i32 : C_NX / 2
	C_NY_2 : i32 : C_NY / 2

	C_NX_3 : f64 = 0.3 * f64( C_NX )
	C_NY_3 : f64 = 0.3 * f64( C_NY )

    C_SEED :: 42
    my_rand := rand.create( C_SEED )

	for tt := 0; tt < 1000000 ; tt += 1 {
		if tt % 10000 == 0 {
			fmt.printf( "iteration %v \n", tt )
		}

		for	t : i32 = 0; t < C_TMAX; t += 1 {
			// Choose a	random point in	same range.
			x := f64( 6 * rand.float32( & my_rand ) - 3 )
			y := f64( 6 * rand.float32( & my_rand ) - 3 )

			// Determine state of this point, draw 	if it escapes.
			ret_val, n_possible := iterate( x, y, &xy_seq_x, &xy_seq_y )
			if ret_val {
				n = n_possible
				for	i : i32 = 0; i < n; i += 1 {
					seq_x := xy_seq_x[i]
					seq_y := xy_seq_y[i]
					// ix = int(0.3*NX*(seq_x+0.5) + NX/2);
					// iy = int(0.3*NY*seq_y + NY/2);
					ix := i32( f64( C_NX_3 ) * ( seq_x + 0.5 ) + f64( C_NX_2 ) )
					iy := i32( f64( C_NY_3 ) * seq_y + f64( C_NY_2 ) )
					if ( ( ix >= 0 ) && ( iy >= 0 ) ) &&
						( ix < C_NX ) && ( iy < C_NY ) {
						image_out[ iy ][ ix ] += 1
					}
				}
			}
		}
	}

	// Write
	write_image( filename, &image_out, C_NX, C_NY )
}

iterate :: proc ( x0, y0 : f64,  seq_x, seq_y : ^[C_NMAX]f64 ) -> (bool, i32) {

	x : f64 = 0.0
	y : f64 = 0.0

	for	i : i32 = 0; i < C_NMAX; i += 1 {
		xnew := x * x - y * y + x0
		ynew := 2 * x * y + y0
		seq_x[ i ] = xnew
		seq_y[ i ] = ynew
		if ( xnew * xnew + ynew * ynew ) > 10 {
			//n = 1
			return true, i
		}
		x = xnew
		y = ynew
	}
	return false, -1
}


write_image :: proc ( filename : string, image_array : ^[ C_NX ][ C_NY ]f64, width, height : i32 ) {

	// Find the largest and the lowest density value
	biggest  : f64 = 0
	smallest : f64 = bits.I32_MAX

    for y := 0; y < int(C_NY); y += 1 {
        for x := 0; x < int(C_NX); x += 1 {
            biggest  = max( biggest,  image_array[ x ][ y ] )
			smallest = min( smallest, image_array[ x ][ y ] )
        }
    }

	fmt.printf("Density value range: %v to %v ", smallest, biggest )

	// Write the image - raw uncompressed bytes
    my_image: image.Image

    // set image metadata
    my_image.channels = 4
    my_image.depth    = 8
    my_image.width    = int( width )   // 512
    my_image.height   = int( height )  // 512

    // allocate a buffer of 0s
    buffer_size := image.compute_buffer_size( int( width ), int( height ), 4, 8 )
    bytes.buffer_init_allocator( & my_image.pixels, buffer_size, buffer_size )
    defer bytes.buffer_destroy( & my_image.pixels)

    C_RED   :: 0
    C_GREEN :: 1
    C_BLUE  :: 2
    C_ALPHA :: 3

    // fmt.printf( " my_image.pixels.buf len() : [%v] \n", len( my_image.pixels.buf )  )

	for x := 0; x < int(width); x += 1 {
		for y := 0; y < int(height); y += 1 {
			ramp := 2 * ( image_array[ x ][ y ] - smallest ) / ( biggest - smallest )
			if ramp > 1{
				ramp = 1
			}
			ramp = math.pow( ramp, 0.5 )
            
            // The buffer is contigous, so we can use a single index.
            C_NUM_COMPONENTS :: 4   //4  // RGBA
            pos : int = x * C_NUM_COMPONENTS + y * int(C_NX) * C_NUM_COMPONENTS

            my_image.pixels.buf[ pos + C_RED   ] = u8( 255 * ramp )
            my_image.pixels.buf[ pos + C_GREEN ] = u8( 255 * ramp )
            my_image.pixels.buf[ pos + C_BLUE  ] = u8( 255 * ramp )
            my_image.pixels.buf[ pos + C_ALPHA ] = u8( 255 )
		}
	}

    // Save TGA
    fmt.printf( "Saving image to %v\n", filename )
    err := tga.save_to_file( filename, &my_image)
    if err != nil {
        fmt.println(err)
    }
}

