include <materials.scad>
use <controls.scad>

/**
 * corner_rounding() - Helper module for rounding square corners
 * r: Radius of corner rounding
 *
 * Can be used to produce rounded corners by taking difference with outside
 * corners, and taking union with inside corners.
 */
module corner_rounding(r)
{
	if (r) difference() {
		square([r*2,r*2], center=true);
		translate([ r, r]) circle(r);
		translate([-r, r]) circle(r);
		translate([ r,-r]) circle(r);
		translate([-r,-r]) circle(r);
	}
}

/**
 * rounded_square() - 2D square module with rounded corners
 */
module rounded_square(size, r)
{
	difference() {
		square(size);
		if (r) {
			translate([0,0]) corner_rounding(r);
			translate([size[0],0]) corner_rounding(r);
			translate([0,size[1]]) corner_rounding(r);
			translate(size) corner_rounding(r);
		}
	}

	/* Alternate implementation using hull() instead of trimming corners
	if (r) hull() {
		translate([r,r]) circle(r);
		translate([size[0]-r,r]) circle(r);
		translate([size[0]-r,size[1]-r]) circle(r);
		translate([r,size[1]-r]) circle(r);
	} else {
		square(size);
	}
	*/
}

/**
 * panel_profile() - Creates a 2D outline of the control panel
 *
 * size: array of [width,height] describing the size of the panel
 * inset: (optional) array of [width,height] describing dimensions
 *        of the top edge of the panel if needed to fit inside a
 *        cabinet that is narrower than the control panel.
 * r: (optional) Radius of circle for a curved front control panel
 * corner: radius of corners on control panel, both for aesthetics
 *         and limitations of manufacturing process (ie. when using
 *         router to cut out the panel.
 */
module panel_profile(size, inset, r, corner=10)
{
	// Calculate the front and back edge locations of the centre section
	back = inset ? inset[1] : 0;
	front = r ? sqrt(pow(r-corner,2)-pow(size[0]/2-corner,2)) + corner - (r-size[1]) : size[1];
	centre_size=[size[0], front-back];

	hull() {
		translate([-size[0]/2,-front,0])
			rounded_square(centre_size,corner);

		if (r) intersection() {
			translate([0,r-size[1],0]) circle(r,$fa=2);
			translate([-size[0]/2+corner, -size[1]])
				square([size[0]-corner*2,size[1]-front+5]);
		}
	}

	if (inset) {
		// Inset part of the panel
		translate([-inset[0]/2,-(inset[1]+corner),0])
			rounded_square([inset[0], inset[1]+corner],corner);

		// Inside corner rounding between inset and center panel
		translate([-inset[0]/2,-inset[1]]) corner_rounding(corner);
		translate([ inset[0]/2,-inset[1]]) corner_rounding(corner);
	}
}

/* Some canned control cluster layouts */
player_config_1 = [[8, "red", "sega2"]];
player_config_2 = [[6, "red", "sega2"],
                   [6, "blue", "sega2"]];
player_config_3 = [[6, "red", "sega2"],
                   [6, "blue", "sega2"],
                   [6, "yellow", "sega2"]];
player_config_4 = [[4, "red", "sega2"],
                   [6, "blue", "sega2"],
                   [6, "green", "sega2"],
                   [4, "yellow", "sega2"]];
player_config_5 = [[4, "red", "sega2"],
                   [6, "blue", "sega2"],
                   [6, "purple", "trackball3"],
                   [6, "green", "sega2"],
                   [4, "yellow", "sega2"]];

module panel_controls(size, r, cutout=false, start_spacing=120,
                      start_colour="white", pc=player_config_4,
                      coin_spacing=50, trackball=true, undermount=0)
{
	curve_origin=r-size[1];
	num_players = len(pc);
	spacing = (size[0]-50)/num_players;
	curve_angle = asin((spacing/2)/(r-100))*2;

	// Player Start buttons
	translate([-start_spacing*(num_players-1)/2, -40, 0])
		for (i=[0:num_players-1]) {
			translate([start_spacing*i-coin_spacing/2,0,0]) {
				button(color=start_colour, cutout=cutout);
				translate([0,-40,0]) text("start", halign="center");
			}
			if (coin_spacing > 0) {
				translate([start_spacing*i+coin_spacing/2,0,0]) {
					button(color=pc[i][1], cutout=cutout);
					translate([0,-40,0]) text("coin", halign="center");
				}
			}
		}

	// Game Controls
	for (idx=[0:len(pc)-1]) {
		p = pc[idx];
		offset = idx - (num_players-1)/2;
		if (r) {
			translate([0,curve_origin,0]) rotate([0,0,offset*curve_angle])
				translate([0,-r+100 ,0]) {
					control_cluster(undermount=undermount,
						   cutout=cutout,
						   max_buttons=p[0], color=p[1], layout_name=p[2]);
					// Guide lines
					rotate([0,90,0]) square([1, r]);
				}
		} else {
			translate([offset*spacing, -size[1]+100])
				control_cluster(undermount=undermount, cutout=cutout,
						max_buttons=p[0], color=p[1]);
		}
	}

	if (trackball)
		translate([0,-size[1]+225,0]) utrak_trackball(cutout=cutout);
}

/**
 * panel_multilayer(): construct a panel out of multiple layers
 * layers: Array of layer descriptions. Each layer is a nested array containing
 *         layer colour and layer thickness (mm).
 * i: (do not use) internal iteration variable
 */
module panel_multilayer(layers=[[[0,0,1,.3], plex_thick],
                                [FiberBoard, mdf_thick]], i=0)
{
	if (i < len(layers)) {
		// Draw the bottom layers first on the assumption that the top
		// layer will be transparent. OpenSCAD Preview shows the right
		// thing if transparent items are added last.
		translate([0,0,-layers[i][1]-0.2])
			panel_multilayer(layers, i+1) children();
		// Add the layer
		color(layers[i][0]) translate([0,0,-layers[i][1]])
			linear_extrude(layers[i][1], convexity=10) children();
	}
}

// Default dimensions used for convenience in testing
default_size = [900, 400];
default_inset = [602, 150];
default_radius = 1000;

/**
 * panel() - Full control panel including multilayer board and control placement
 * size: array [width,height] of outside dimensions of the control panel
 * inset: (optional) array [width,height] of dimensions of inset section at
 *        back of panel (ie. to fit into cabinet narrower than control panel).
 * r: (optional) Radius of curve used for front edge of control panel. Use undef
 *    or 0 for no curve.
 */
module panel(size=default_size, inset=default_inset, r=default_radius,
             trackball, pc=player_config_4, show_controls=true)
{
	if (show_controls)
		panel_controls(size, r=r, pc=pc, trackball=trackball,
		               undermount=plex_thick+0.1);
	difference() {
		panel_multilayer() panel_profile(size, inset, r=r);
		panel_controls(size, r=r, pc=pc, trackball=trackball,
		               undermount=plex_thick+0.1, cutout=true);
	}
}

test_radius=[0, 1000, 800];
test_config=[
	[player_config_1, [602,300], undef, false],
	[player_config_2, [602,275], undef, false],
	[player_config_2, [602,300], undef, true],
	[player_config_3, default_size, default_inset, false],
	[player_config_4, default_size, default_inset, false],
	//[player_config_5, [1000,500], default_inset, false],
];

for (i=[0:len(test_radius)-1]) {
	xoff = (i-(len(test_radius)-1)/2)*default_size[0]*1.2;
	for (j=[0:len(test_config)-1]) {
		yoff = (j-(len(test_config)-1)/2)*default_size[1]*1.4;
		translate([xoff,yoff])
			panel(size=test_config[j][1],inset=test_config[j][2],
			      pc=test_config[j][0],trackball=test_config[j][3],
			      r=test_radius[i],show_controls=(i==1 && j==1));
	}
}
//projection(cut=true) translate([0,0,plex_thick/2]) panel();
//projection(cut=true) translate([0,0,plex_thick+0.3]) panel();
//projection(cut=true) translate([0,0,plex_thick+mdf_thick]) panel();
