local ShrinkConfig = {}

ShrinkConfig.BaseScale = 1.0
ShrinkConfig.MinScale = 0.1
ShrinkConfig.MaxLevel = 170

-- Linear ramp from BaseScale (level 1) down to MinScale (level 150).
-- Precomputed so individual levels can be hand-tuned here without touching code.
ShrinkConfig.ScaleByLevel = {
	[1] = 1.0, [2] = 0.995, [3] = 0.989, [4] = 0.984, [5] = 0.979, [6] = 0.973, [7] = 0.968, [8] = 0.962, [9] = 0.957, [10] = 0.952,
	[11] = 0.946, [12] = 0.941, [13] = 0.936, [14] = 0.93, [15] = 0.925, [16] = 0.919, [17] = 0.914, [18] = 0.909, [19] = 0.903, [20] = 0.898,
	[21] = 0.893, [22] = 0.887, [23] = 0.882, [24] = 0.877, [25] = 0.871, [26] = 0.866, [27] = 0.86, [28] = 0.855, [29] = 0.85, [30] = 0.844,
	[31] = 0.839, [32] = 0.834, [33] = 0.828, [34] = 0.823, [35] = 0.817, [36] = 0.812, [37] = 0.807, [38] = 0.801, [39] = 0.796, [40] = 0.791,
	[41] = 0.785, [42] = 0.78, [43] = 0.774, [44] = 0.769, [45] = 0.764, [46] = 0.758, [47] = 0.753, [48] = 0.748, [49] = 0.742, [50] = 0.737,
	[51] = 0.732, [52] = 0.726, [53] = 0.721, [54] = 0.715, [55] = 0.71, [56] = 0.705, [57] = 0.699, [58] = 0.694, [59] = 0.689, [60] = 0.683,
	[61] = 0.678, [62] = 0.672, [63] = 0.667, [64] = 0.662, [65] = 0.656, [66] = 0.651, [67] = 0.646, [68] = 0.64, [69] = 0.635, [70] = 0.63,
	[71] = 0.624, [72] = 0.619, [73] = 0.613, [74] = 0.608, [75] = 0.603, [76] = 0.597, [77] = 0.592, [78] = 0.587, [79] = 0.581, [80] = 0.576,
	[81] = 0.57, [82] = 0.565, [83] = 0.56, [84] = 0.554, [85] = 0.549, [86] = 0.544, [87] = 0.538, [88] = 0.533, [89] = 0.528, [90] = 0.522,
	[91] = 0.517, [92] = 0.511, [93] = 0.506, [94] = 0.501, [95] = 0.495, [96] = 0.49, [97] = 0.485, [98] = 0.479, [99] = 0.474, [100] = 0.468,
	[101] = 0.463, [102] = 0.458, [103] = 0.452, [104] = 0.447, [105] = 0.442, [106] = 0.436, [107] = 0.431, [108] = 0.426, [109] = 0.42, [110] = 0.415,
	[111] = 0.409, [112] = 0.404, [113] = 0.399, [114] = 0.393, [115] = 0.388, [116] = 0.383, [117] = 0.377, [118] = 0.372, [119] = 0.366, [120] = 0.361,
	[121] = 0.356, [122] = 0.35, [123] = 0.345, [124] = 0.34, [125] = 0.334, [126] = 0.329, [127] = 0.323, [128] = 0.318, [129] = 0.313, [130] = 0.307,
	[131] = 0.302, [132] = 0.297, [133] = 0.291, [134] = 0.286, [135] = 0.281, [136] = 0.275, [137] = 0.27, [138] = 0.264, [139] = 0.259, [140] = 0.254,
	[141] = 0.248, [142] = 0.243, [143] = 0.238, [144] = 0.232, [145] = 0.227, [146] = 0.221, [147] = 0.216, [148] = 0.211, [149] = 0.205, [150] = 0.2,
	[151] = 0.196, [152] = 0.191, [153] = 0.186, [154] = 0.181, [155] = 0.176, [156] = 0.171, [157] = 0.166, [158] = 0.161, [159] = 0.156, [160] = 0.151,
	[161] = 0.146, [162] = 0.141, [163] = 0.136, [164] = 0.131, [165] = 0.126, [166] = 0.121, [167] = 0.116, [168] = 0.111, [169] = 0.106, [170] = 0.1,
}

function ShrinkConfig.GetScaleForLevel(level: number): number
	if level <= 1 then
		return ShrinkConfig.BaseScale
	end
	if level >= ShrinkConfig.MaxLevel then
		return ShrinkConfig.MinScale
	end
	return ShrinkConfig.ScaleByLevel[level]
end

-- Shared clamp formula for "what scale should this character actually be
-- right now" - the level-based floor, optionally overridden up to a manually
-- chosen customScale (never below the floor, never above BaseScale). Every
-- client computes this identically for every player from the same replicated
-- Level/CustomScale inputs, which is what keeps everyone's view in sync
-- without the server ever calling ScaleTo itself.
function ShrinkConfig.GetEffectiveScale(level: number, customScale: number?): number
	local minScale = ShrinkConfig.GetScaleForLevel(level)
	if customScale then
		return math.clamp(customScale, minScale, ShrinkConfig.BaseScale)
	end
	return minScale
end

-- ShrinkScore is a purely cosmetic, ever-increasing display number for the
-- level-up notification - it is NOT the real character scale (see
-- GetScaleForLevel above) and is unrelated to the "Shrink" XP/currency stat
-- (Template.Shrink). Raw scale deltas near 1.0 are visually unappealing, so
-- this maps level 1 -> 1000 at MaxLevel (where the real scale bottoms out),
-- then keeps climbing a flat amount per level forever after, since Level
-- itself is uncapped (see LevelConfig/RebirthConfig).
ShrinkConfig.MaxShrinkScore = 1000
ShrinkConfig.PostCapShrinkScorePerLevel = 50

ShrinkConfig.ShrinkScoreByLevel = {
	[1] = 1, [2] = 8, [3] = 14, [4] = 21, [5] = 28, [6] = 35, [7] = 41, [8] = 48, [9] = 55, [10] = 61,
	[11] = 68, [12] = 75, [13] = 81, [14] = 88, [15] = 95, [16] = 102, [17] = 108, [18] = 115, [19] = 122, [20] = 128,
	[21] = 135, [22] = 142, [23] = 149, [24] = 155, [25] = 162, [26] = 169, [27] = 175, [28] = 182, [29] = 189, [30] = 195,
	[31] = 202, [32] = 209, [33] = 216, [34] = 222, [35] = 229, [36] = 236, [37] = 242, [38] = 249, [39] = 256, [40] = 262,
	[41] = 269, [42] = 276, [43] = 283, [44] = 289, [45] = 296, [46] = 303, [47] = 309, [48] = 316, [49] = 323, [50] = 330,
	[51] = 336, [52] = 343, [53] = 350, [54] = 356, [55] = 363, [56] = 370, [57] = 376, [58] = 383, [59] = 390, [60] = 397,
	[61] = 403, [62] = 410, [63] = 417, [64] = 423, [65] = 430, [66] = 437, [67] = 444, [68] = 450, [69] = 457, [70] = 464,
	[71] = 470, [72] = 477, [73] = 484, [74] = 490, [75] = 497, [76] = 504, [77] = 511, [78] = 517, [79] = 524, [80] = 531,
	[81] = 537, [82] = 544, [83] = 551, [84] = 557, [85] = 564, [86] = 571, [87] = 578, [88] = 584, [89] = 591, [90] = 598,
	[91] = 604, [92] = 611, [93] = 618, [94] = 625, [95] = 631, [96] = 638, [97] = 645, [98] = 651, [99] = 658, [100] = 665,
	[101] = 671, [102] = 678, [103] = 685, [104] = 692, [105] = 698, [106] = 705, [107] = 712, [108] = 718, [109] = 725, [110] = 732,
	[111] = 739, [112] = 745, [113] = 752, [114] = 759, [115] = 765, [116] = 772, [117] = 779, [118] = 785, [119] = 792, [120] = 799,
	[121] = 806, [122] = 812, [123] = 819, [124] = 826, [125] = 832, [126] = 839, [127] = 846, [128] = 852, [129] = 859, [130] = 866,
	[131] = 873, [132] = 879, [133] = 886, [134] = 893, [135] = 899, [136] = 906, [137] = 913, [138] = 920, [139] = 926, [140] = 933,
	[141] = 940, [142] = 946, [143] = 953, [144] = 960, [145] = 966, [146] = 973, [147] = 980, [148] = 987, [149] = 993, [150] = 1000,
}

function ShrinkConfig.GetShrinkScoreForLevel(level: number): number
	if level <= 1 then
		return 1
	end
	if level >= ShrinkConfig.MaxLevel then
		return ShrinkConfig.MaxShrinkScore + (level - ShrinkConfig.MaxLevel) * ShrinkConfig.PostCapShrinkScorePerLevel
	end
	return ShrinkConfig.ShrinkScoreByLevel[level]
end

return ShrinkConfig
