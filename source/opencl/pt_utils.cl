/**
 * MACRO: Get half-vector.
 * @param  {const float3} v
 * @param  {const float3} w
 * @return {float3}         Half-vector of v and w.
 */
#define bisect( v, w ) ( fast_normalize( ( v ) + ( w ) ) )


/**
 * Fresnel factor.
 * @param  {const float} u
 * @param  {const float} c Reflection factor.
 * @return {float}
 */
inline float fresnel( const float u, const float c ) {
	const float v = 1.0f - u;
	return c + ( 1.0f - c ) * v * v * v * v * v;
}


inline void swap( float* a, float* b ) {
	const float tmp = *a;
	*a = *b;
	*b = tmp;
}


/**
 * Solve a cubic function: a0*x^3 + a1*x^2 + a2*x^1 + a3 = 0
 * @param  {const float} a0
 * @param  {const float} a1
 * @param  {const float} a2
 * @param  {const float} a3
 * @param  {float[3]} x     Output. Found real solutions.
 * @return {char}           Number of found real solutions.
 */
char solveCubic( const float a0, const float a1, const float a2, const float a3, float x[3] ) {
	#define THIRD 0.3333333333f
	#define THIRD_HALF 0.166666666f
	float w, p, q, dis, phi;

	if( fabs( a0 ) > EPSILON10 ) {
		// cubic problem
		w = native_divide( a1, a0 ) * THIRD;
		p = native_divide( a2, a0 ) * THIRD - w * w;
		p = p * p * p;
		q = 0.5f * native_divide( a2 * w - a3, a0 ) - w * w * w;
		dis = q * q + p;

		if( dis < 0.0f ) {
			// three real solutions
			phi = acos( clamp( native_divide( q, native_sqrt( -p ) ), -1.0f, 1.0f ) );
			p = 2.0f * pow( -p, THIRD_HALF );

			const float u[3] = {
				p * native_cos( phi * THIRD ) - w,
				p * native_cos( ( phi + 2.0f * M_PI ) * THIRD ) - w,
				p * native_cos( ( phi + 4.0f * M_PI ) * THIRD ) - w
			};

			x[0] = fmin( u[0], fmin( u[1], u[2] ) );
			x[1] = fmax( fmin( u[0], u[1] ), fmax( fmin( u[0], u[2] ), fmin( u[1], u[2] ) ) );
			x[2] = fmax( u[0], fmax( u[1], u[2] ) );
			// Minimize rounding errors through a Newton iteration
			x[0] -= native_divide(
				a3 + x[0] * ( a2 + x[0] * ( a1 + x[0] * a0 ) ),
				a2 + x[0] * ( 2.0f * a1 + x[0] * 3.0f * a0 )
			);
			x[1] -= native_divide(
				a3 + x[1] * ( a2 + x[1] * ( a1 + x[1] * a0 ) ),
				a2 + x[1] * ( 2.0f * a1 + x[1] * 3.0f * a0 )
			);
			x[2] -= native_divide(
				a3 + x[2] * ( a2 + x[2] * ( a1 + x[2] * a0 ) ),
				a2 + x[2] * ( 2.0f * a1 + x[2] * 3.0f * a0 )
			);

			return 3;
		}
		else {
			// only one real solution!
			dis = native_sqrt( dis );
			x[0] = cbrt( q + dis ) + cbrt( q - dis ) - w;
			// Newton iteration
			x[0] -= native_divide(
				a3 + x[0] * ( a2 + x[0] * ( a1 + x[0] * a0 ) ),
				a2 + x[0] * ( 2.0f * a1 + x[0] * 3.0f * a0 )
			);

			return 1;
		}
	}
	else if( fabs( a1 ) > EPSILON10 ) {
		// quadratic problem
		p = 0.5f * native_divide( a2, a1 );
		dis = p * p - native_divide( a3, a1 );

		if( dis >= 0.0f ) {
			const float dis_sqrt = native_sqrt( dis );

			// 2 real solutions
			x[0] = -p - dis_sqrt;
			x[1] = -p + dis_sqrt;
			// Newton iteration
			x[0] -= native_divide(
				a3 + x[0] * ( a2 + x[0] * a1 ),
				a2 + x[0] * 2.0f * a1
			);
			x[1] -= native_divide(
				a3 + x[1] * ( a2 + x[1] * a1 ),
				a2 + x[1] * 2.0f * a1
			);

			return 2;
		}
	}
	else if( fabs( a2 ) > EPSILON10 ) {
		// linear equation
		x[0] = native_divide( -a3, a2 );

		return 1;
	}

	return 0;

	#undef THIRD
	#undef THIRD_HALF
}


/**
 * Get two planes from a ray that have the ray as intersection.
 * The planes are described in the Hesse normal form.
 * @param  {const ray4*} ray The ray.
 * @return {rayPlanes}       The planes describing the ray.
 */
rayPlanes getPlanesFromRay( const ray4* ray ) {
	rayPlanes rp;
	float3 nCand = ray->dir.zxy;

	// if( fabs( ray->dir.z ) >= EPSILON5 ) {
	// 	// nCand.z = native_divide( -nCand.x * ray->dir.x - nCand.y * ray->dir.y, ray->dir.z );
	// 	nCand.z = native_divide( -ray->dir.x - ray->dir.y, ray->dir.z );
	// }
	// else if( fabs( ray->dir.y ) >= EPSILON5 ) {
	// 	// nCand.y = native_divide( -nCand.x * ray->dir.x - nCand.z * ray->dir.z, ray->dir.y );
	// 	nCand.y = native_divide( -ray->dir.x - ray->dir.z, ray->dir.y );
	// }
	// else {
	// 	// nCand.x = native_divide( -nCand.y * ray->dir.y - nCand.z * ray->dir.z, ray->dir.x );
	// 	nCand.x = native_divide( -ray->dir.y - ray->dir.z, ray->dir.x );
	// }

	if( fabs( ray->dir.x ) > fabs( ray->dir.y ) ) {
		if( fabs( ray->dir.x ) > fabs( ray->dir.z ) ) {
			nCand.x = native_divide( -nCand.y * ray->dir.y - nCand.z * ray->dir.z, ray->dir.x );
		}
		else {
			nCand.z = native_divide( -nCand.x * ray->dir.x - nCand.y * ray->dir.y, ray->dir.z );
		}
	}
	else {
		if( fabs( ray->dir.y ) > fabs( ray->dir.z ) ) {
			nCand.y = native_divide( -nCand.x * ray->dir.x - nCand.z * ray->dir.z, ray->dir.y );
		}
		else {
			nCand.z = native_divide( -nCand.x * ray->dir.x - nCand.y * ray->dir.y, ray->dir.z );
		}
	}

	rp.n1 = fast_normalize( nCand );


	// if( fabs( fast_length( ray->dir.xyz - ray->dir.zxy ) ) > EPSILON5 ) {
	// 	rp.n1 = fast_normalize( cross( ray->dir.xyz, ray->dir.zxy ) );
	// }
	// else {
	// 	float3 alt1 = { -ray->dir.z, -ray->dir.x, ray->dir.y };
	// 	rp.n1 = fast_normalize( cross( ray->dir.xyz, alt1 ) );
	// }

	rp.n2 = cross( rp.n1, ray->dir.xyz );
	rp.n2 = fast_normalize( rp.n2 );

	rp.o1 = dot( rp.n1, ray->origin.xyz );
	rp.o2 = dot( rp.n2, ray->origin.xyz );

	return rp;
}


/**
 *
 * @param  {const face_t} face
 * @param  {const float3} tuv
 * @return {float4}
 */
inline float4 getTriangleNormal( const face_t* face, const float u, const float v, const float w ) {
	return (float4)( fast_normalize( face->an.xyz * u + face->bn.xyz * v + face->cn.xyz * w ), 0.0f );
}


inline float3 getTriangleNormalS(
	const float u, const float v, const float w,
	const float3 C12, const float3 C23, const float3 C31, const float3 E23, const float3 E31
) {
	const float3 du = ( w - u ) * C31 + v * ( C12 - C23 ) + E31;
	const float3 dv = ( w - v ) * C23 + u * ( C12 - C31 ) - E23;

	return fast_normalize( cross( du, dv ) );
}


inline float3 getTriangleReflectionVec( const float3 view, const float3 np ) {
	return view - 2.0f * np * dot( view, np );
}


inline float4 getPhongTessNormal(
	const face_t* face, const float3 rayDir, const float u, const float v, const float w,
	const float3 C1, const float3 C2, const float3 C3, const float3 E12, const float3 E20
) {
	const float3 ns = getTriangleNormalS( u, v, w, C1, C2, C3, E12, E20 );
	const float4 np = getTriangleNormal( face, u, v, w );
	const float3 r = getTriangleReflectionVec( rayDir, np.xyz );

	return ( dot( ns, r ) < 0.0f ) ? (float4)( ns, 0.0f ) : np;
}


/**
 * New direction for (perfectly) diffuse surfaces.
 * (Well, depening on the given parameters.)
 * @param  {const float4} nl   Normal (unit vector).
 * @param  {const float}  phi
 * @param  {const float}  sina
 * @param  {const float}  cosa
 * @return {float4}
 */
float4 jitter(
	const float4 nl, const float phi, const float sina, const float cosa
) {
	const float4 u = fast_normalize( cross( nl.yzxw, nl ) );
	const float4 v = fast_normalize( cross( nl, u ) );

	return fast_normalize(
		fast_normalize(
			u * native_cos( phi ) +
			v * native_sin( phi )
		) * sina + nl * cosa
	);
}


/**
 * Project a point on a plane.
 * @param  {float3} q Point to project.
 * @param  {float3} p Point of plane.
 * @param  {float3} n Normal of plane.
 * @return {float3}   Projected point.
 */
inline float3 projectOnPlane( const float3 q, const float3 p, const float3 n ) {
	return q - dot( q - p, n ) * n;
}


/**
 * MACRO: Apply Lambert's cosine law for light sources.
 * @param  {float4} n Normal of the surface the light hits.
 * @param  {float4} l Normalized direction to the light source.
 * @return {float}
 */
#define lambert( n, l ) ( fmax( dot( ( n ).xyz, ( l ).xyz ), 0.0f ) )


/**
 * MACRO: Projection of h orthogonal n, with n being a unit vector.
 * @param  {const float3} h
 * @param  {const float3} n
 * @return {float3}         Projection of h onto n.
 */
#define projection( h, n ) ( dot( ( h ).xyz, ( n ).xyz ) * ( n ) )


/**
 *
 * @param  {float*} seed
 * @return {float}
 */
inline const float rand( float* seed ) {
	float i;
	*seed += 1.0f;

	return fract( native_sin( *seed ) * 43758.5453123f, &i );
}


// #define RAND_A 16807.0f
// #define RAND_M 2147483647.0f
// #define RAND_MRECIP 4.656612875245797e-10

// // Park-Miller RNG
// inline const float rand( int* seed ) {
// 	const float temp = (*seed) * RAND_A;
// 	*seed = (int)( temp - RAND_M * floor( temp * RAND_MRECIP ) );

// 	return (*seed) * RAND_MRECIP;
// }


/**
 * MACRO: Reflect a ray.
 * @param  {float4} dir    Direction of ray.
 * @param  {float4} normal Normal of surface.
 * @return {float4}        Reflected ray.
 */
#define reflect( dir, normal ) ( ( dir ) - 2.0f * dot( ( normal ).xyz, ( dir ).xyz ) * ( normal ) )


/**
 * Get the a new direction for a ray hitting a transparent surface (glass etc.).
 * @param  {const ray4*}     currentRay The current ray.
 * @param  {const material*} mtl        Material of the hit surface.
 * @param  {float*}          seed       Seed for the random number generator.
 * @return {float4}                     A new direction for the ray.
 */
float4 refract( const ray4* ray, const material* mtl, float* seed ) {
	#define DIR ( ray->dir )
	#define N ( ray->normal )

	const bool into = ( dot( N.xyz, DIR.xyz ) < 0.0f );
	const float4 nl = into ? N : -N;

	const float m1 = into ? NI_AIR : mtl->Ni;
	const float m2 = into ? mtl->Ni : NI_AIR;
	const float m = native_divide( m1, m2 );

	const float cosI = -dot( DIR.xyz, nl.xyz );
	const float sinT2 = m * m * ( 1.0f - cosI * cosI );

	// Critical angle. Total internal reflection.
	if( sinT2 > 1.0f ) {
		return reflect( DIR, nl );
	}


	// Reflectance and transmission

	const float r0 = native_divide( m1 - m2, m1 + m2 );
	const float c = ( m1 > m2 ) ? native_sqrt( 1.0f - sinT2 ) : cosI;
	const float reflectance = fresnel( c, r0 * r0 );
	// transmission = 1.0f - reflectance

	#define COS_T ( native_sqrt( 1.0f - sinT2 ) )
	#define DO_REFRACT ( reflectance < rand( seed ) )

	const float4 newRay = DO_REFRACT
	                    ? m * DIR + ( m * cosI - COS_T ) * nl
	                    : reflect( DIR, nl );

	return fast_normalize( newRay );

	#undef DIR
	#undef N
	#undef COS_T
	#undef DO_REFRACT
}


/**
 * Initialize a float array with a default value.
 * @param {float*} arr  The array to initialize.
 * @param {float}  val  The default value to set.
 */
inline void setArray( float* arr, float val ) {
	for( int i = 0; i < SPEC; i++ ) {
		arr[i] = val;
	}
}
