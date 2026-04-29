const mongoose = require("mongoose");
require("dotenv").config();

const Scheme = require("./models/Scheme");

// 🔥 STEP 1: Paste your dataset below
const schemes = [
  // 👇 PASTE YOUR 55 SCHEMES JSON HERE (array of objects — not nested arrays)
  {
      "scheme_name": "PM Kisan Samman Nidhi",
      "scheme_type": "Central",
      "state": "All",
      "description": "Provides ₹6000 per year to small and marginal farmers in three installments.",
      "benefits": [
        "Direct income support",
        "Helps in farming expenses",
        "Improves farmer livelihood"
      ],
      "application_link": "https://pmkisan.gov.in",
      "last_date": "Ongoing",
      "cropTypes": ["All"]
    },
    {
      "scheme_name": "Pradhan Mantri Fasal Bima Yojana",
      "scheme_type": "Central",
      "state": "All",
      "description": "Crop insurance scheme covering losses due to natural disasters.",
      "benefits": [
        "Low premium insurance",
        "Covers crop loss",
        "Financial protection"
      ],
      "application_link": "https://pmfby.gov.in",
      "last_date": "Seasonal",
      "cropTypes": ["Rice", "Wheat", "Cotton", "Maize", "Pulses"]
    },
    {
      "scheme_name": "Soil Health Card Scheme",
      "scheme_type": "Central",
      "state": "All",
      "description": "Provides soil health reports and fertilizer recommendations.",
      "benefits": [
        "Improves soil fertility",
        "Optimizes fertilizer usage",
        "Boosts yield"
      ],
      "application_link": "https://soilhealth.dac.gov.in",
      "last_date": "Ongoing",
      "cropTypes": ["All"]
    },
    {
      "scheme_name": "Kisan Credit Card",
      "scheme_type": "Central",
      "state": "All",
      "description": "Provides short-term credit for agricultural needs.",
      "benefits": [
        "Easy loan access",
        "Low interest rates",
        "Flexible repayment"
      ],
      "application_link": "https://www.myscheme.gov.in/schemes/kcc",
      "last_date": "Ongoing",
      "cropTypes": ["All"]
    },
    {
      "scheme_name": "National Mission on Oilseeds and Oil Palm",
      "scheme_type": "Central",
      "state": "All",
      "description": "Promotes production of oilseeds and oil palm cultivation.",
      "benefits": [
        "Subsidy for seeds",
        "Training support",
        "Improves oilseed productivity"
      ],
      "application_link": "https://nmoop.gov.in",
      "last_date": "Ongoing",
      "cropTypes": ["Oilseeds", "Palm"]
    },
    {
      "scheme_name": "Paramparagat Krishi Vikas Yojana",
      "scheme_type": "Central",
      "state": "All",
      "description": "Promotes organic farming and sustainable agriculture.",
      "benefits": [
        "Financial support for organic farming",
        "Improves soil health",
        "Better market prices"
      ],
      "application_link": "https://pgsindia-ncof.gov.in",
      "last_date": "Ongoing",
      "cropTypes": ["Organic", "Vegetables", "Fruits"]
    },
    {
      "scheme_name": "Rashtriya Krishi Vikas Yojana",
      "scheme_type": "Central",
      "state": "All",
      "description": "Supports agricultural infrastructure and productivity improvement.",
      "benefits": [
        "Infrastructure development",
        "Farmer support programs",
        "Boosts production"
      ],
      "application_link": "https://rkvy.nic.in",
      "last_date": "Ongoing",
      "cropTypes": ["All"]
    },
    {
      "scheme_name": "National Food Security Mission",
      "scheme_type": "Central",
      "state": "All",
      "description": "Increases production of rice, wheat, and pulses.",
      "benefits": [
        "Subsidy on seeds",
        "Improved yield",
        "Farmer training"
      ],
      "application_link": "https://nfsm.gov.in",
      "last_date": "Ongoing",
      "cropTypes": ["Rice", "Wheat", "Pulses"]
    },
  
    {
      "scheme_name": "Rythu Bandhu Scheme",
      "scheme_type": "State",
      "state": "Telangana",
      "description": "Provides financial assistance for crop investment.",
      "benefits": [
        "Direct financial support",
        "Covers input costs",
        "Encourages cultivation"
      ],
      "application_link": "https://rythubandhu.telangana.gov.in",
      "last_date": "Seasonal",
      "cropTypes": ["Rice", "Cotton", "Maize"]
    },
    {
      "scheme_name": "Rythu Bima Scheme",
      "scheme_type": "State",
      "state": "Telangana",
      "description": "Life insurance scheme for farmers.",
      "benefits": [
        "Financial security",
        "Insurance coverage",
        "Family support"
      ],
      "application_link": "https://rythubima.telangana.gov.in",
      "last_date": "Ongoing",
      "cropTypes": ["All"]
    },
    {
      "scheme_name": "YSR Rythu Bharosa",
      "scheme_type": "State",
      "state": "Andhra Pradesh",
      "description": "Provides financial support to farmers including tenant farmers.",
      "benefits": [
        "Income support",
        "Helps in farming costs",
        "Supports tenant farmers"
      ],
      "application_link": "https://ysrrythubharosa.ap.gov.in",
      "last_date": "Seasonal",
      "cropTypes": ["Rice", "Groundnut", "Sugarcane"]
    },
    {
      "scheme_name": "YSR Free Crop Insurance",
      "scheme_type": "State",
      "state": "Andhra Pradesh",
      "description": "Provides free crop insurance to farmers.",
      "benefits": [
        "No premium insurance",
        "Crop loss protection",
        "Financial stability"
      ],
      "application_link": "https://apagrisnet.gov.in",
      "last_date": "Seasonal",
      "cropTypes": ["Rice", "Cotton", "Pulses"]
    },
    {
      "scheme_name": "Krishi Bhagya Scheme",
      "scheme_type": "State",
      "state": "Karnataka",
      "description": "Supports irrigation and water conservation for farmers.",
      "benefits": [
        "Water storage support",
        "Irrigation improvement",
        "Increases productivity"
      ],
      "application_link": "https://raitamitra.karnataka.gov.in",
      "last_date": "Ongoing",
      "cropTypes": ["Millets", "Pulses", "Groundnut"]
    },
    {
      "scheme_name": "Kalia Scheme",
      "scheme_type": "State",
      "state": "Odisha",
      "description": "Provides financial assistance to small and marginal farmers.",
      "benefits": [
        "Income support",
        "Support for landless farmers",
        "Livelihood improvement"
      ],
      "application_link": "https://kalia.odisha.gov.in",
      "last_date": "Ongoing",
      "cropTypes": ["Rice", "Vegetables"]
    },
    {
      "scheme_name": "National Horticulture Mission",
      "scheme_type": "Central",
      "state": "All",
      "description": "Promotes horticulture crops like fruits and vegetables.",
      "benefits": ["Subsidy on planting", "Infrastructure support"],
      "application_link": "https://nhm.nic.in",
      "last_date": "Ongoing",
      "cropTypes": ["Fruits", "Vegetables"]
    },
    {
      "scheme_name": "Micro Irrigation Fund",
      "scheme_type": "Central",
      "state": "All",
      "description": "Promotes drip and sprinkler irrigation.",
      "benefits": ["Water saving", "Subsidy for irrigation systems"],
      "application_link": "https://pmksy.gov.in",
      "last_date": "Ongoing",
      "cropTypes": ["All"]
    },
    {
      "scheme_name": "National Bamboo Mission",
      "scheme_type": "Central",
      "state": "All",
      "description": "Supports bamboo cultivation.",
      "benefits": ["Subsidy", "Market linkage"],
      "application_link": "https://nbm.nic.in",
      "last_date": "Ongoing",
      "cropTypes": ["Bamboo"]
    },
  
    {
      "scheme_name": "Annadata Sukhibhava",
      "scheme_type": "State",
      "state": "Andhra Pradesh",
      "description": "Financial support to farmers.",
      "benefits": ["Direct benefit transfer"],
      "application_link": "https://apagrisnet.gov.in",
      "last_date": "Seasonal",
      "cropTypes": ["Rice", "Pulses"]
    },
    {
      "scheme_name": "AP Farm Mechanization Scheme",
      "scheme_type": "State",
      "state": "Andhra Pradesh",
      "description": "Subsidy for farm machinery.",
      "benefits": ["Reduced labor cost", "Increased efficiency"],
      "application_link": "https://apagrisnet.gov.in",
      "last_date": "Ongoing",
      "cropTypes": ["All"]
    },
  
    {
      "scheme_name": "Mission Kakatiya",
      "scheme_type": "State",
      "state": "Telangana",
      "description": "Restoration of irrigation tanks.",
      "benefits": ["Improves irrigation", "Water conservation"],
      "application_link": "https://missionkakatiya.cgg.gov.in",
      "last_date": "Ongoing",
      "cropTypes": ["Rice", "Cotton"]
    },
  
    {
      "scheme_name": "Raitha Siri Scheme",
      "scheme_type": "State",
      "state": "Karnataka",
      "description": "Encourages organic farming.",
      "benefits": ["Financial incentives", "Soil improvement"],
      "application_link": "https://raitamitra.karnataka.gov.in",
      "last_date": "Ongoing",
      "cropTypes": ["Organic"]
    },
    {
      "scheme_name": "Bhoochetana Scheme",
      "scheme_type": "State",
      "state": "Karnataka",
      "description": "Improves soil productivity.",
      "benefits": ["Better yields", "Scientific farming"],
      "application_link": "https://raitamitra.karnataka.gov.in",
      "last_date": "Ongoing",
      "cropTypes": ["Millets", "Pulses"]
    },
  
    {
      "scheme_name": "Uzhavar Sandhai Scheme",
      "scheme_type": "State",
      "state": "Tamil Nadu",
      "description": "Direct farmer markets.",
      "benefits": ["Better price for farmers"],
      "application_link": "https://tn.gov.in",
      "last_date": "Ongoing",
      "cropTypes": ["Vegetables", "Fruits"]
    },
  
    {
      "scheme_name": "Chief Minister Solar Pump Scheme",
      "scheme_type": "State",
      "state": "Maharashtra",
      "description": "Solar pumps for irrigation.",
      "benefits": ["Energy savings", "Subsidy"],
      "application_link": "https://mahadiscom.in",
      "last_date": "Ongoing",
      "cropTypes": ["All"]
    },
    {
      "scheme_name": "Magel Tyala Shettale",
      "scheme_type": "State",
      "state": "Maharashtra",
      "description": "Farm pond scheme.",
      "benefits": ["Water conservation"],
      "application_link": "https://maharashtra.gov.in",
      "last_date": "Ongoing",
      "cropTypes": ["All"]
    },
  
    {
      "scheme_name": "Punjab Crop Diversification Program",
      "scheme_type": "State",
      "state": "Punjab",
      "description": "Encourages shift from paddy to other crops.",
      "benefits": ["Subsidy", "Sustainable farming"],
      "application_link": "https://agripb.gov.in",
      "last_date": "Ongoing",
      "cropTypes": ["Maize", "Pulses"]
    },
  
    {
      "scheme_name": "Mukhyamantri Krishi Ashirwad Yojana",
      "scheme_type": "State",
      "state": "Jharkhand",
      "description": "Financial assistance to farmers.",
      "benefits": ["Income support"],
      "application_link": "https://jharkhand.gov.in",
      "last_date": "Seasonal",
      "cropTypes": ["Rice", "Maize"]
    },
  
    {
      "scheme_name": "Mukhyamantri Krishak Kalyan Yojana",
      "scheme_type": "State",
      "state": "Madhya Pradesh",
      "description": "Farmer welfare scheme.",
      "benefits": ["Financial aid"],
      "application_link": "https://mp.gov.in",
      "last_date": "Ongoing",
      "cropTypes": ["Wheat", "Soybean"]
    },
  
    {
      "scheme_name": "Uttar Pradesh Kisan Uday Yojana",
      "scheme_type": "State",
      "state": "Uttar Pradesh",
      "description": "Energy-efficient pumps for farmers.",
      "benefits": ["Electricity savings"],
      "application_link": "https://up.gov.in",
      "last_date": "Ongoing",
      "cropTypes": ["All"]
    },
  
    {
      "scheme_name": "Kisan Mitra Urja Yojana",
      "scheme_type": "State",
      "state": "Rajasthan",
      "description": "Electricity subsidy for farmers.",
      "benefits": ["Reduced electricity cost"],
      "application_link": "https://rajasthan.gov.in",
      "last_date": "Ongoing",
      "cropTypes": ["All"]
    },
  
    {
      "scheme_name": "West Bengal Krishak Bandhu",
      "scheme_type": "State",
      "state": "West Bengal",
      "description": "Financial assistance to farmers.",
      "benefits": ["Income support"],
      "application_link": "https://krishakbandhu.net",
      "last_date": "Seasonal",
      "cropTypes": ["Rice"]
    },
  
    {
      "scheme_name": "Assam Chief Minister Samagra Gramya Unnayan Yojana",
      "scheme_type": "State",
      "state": "Assam",
      "description": "Rural agriculture development.",
      "benefits": ["Infrastructure support"],
      "application_link": "https://assam.gov.in",
      "last_date": "Ongoing",
      "cropTypes": ["Rice", "Tea"]
    }
];

// 🔥 STEP 2: Insert into DB
const seedData = async () => {
  try {
    await mongoose.connect(process.env.MONGO_URI);
    console.log("MongoDB Connected");

    // Clear existing seeded data
    await Scheme.deleteMany({});
    console.log("Cleared existing schemes");

    // Map seed fields → Mongoose model fields
    const rows = schemes.flat().map((s) => ({
      name:          s.name        || s.scheme_name  || '',
      type:         (s.type        || s.scheme_type  || 'state').toLowerCase(),
      state:         s.state       || '',
      category:      s.category    || 'subsidy',
      description:   s.description || '',
      benefits:      Array.isArray(s.benefits)    ? s.benefits    : [],
      eligibility:   Array.isArray(s.eligibility) ? s.eligibility : [],
      documents:     Array.isArray(s.documents)   ? s.documents   : [],
      applyLink:     s.applyLink   || s.application_link || '',
      deadline:      s.deadline    || s.last_date         || '',
      isAiGenerated: false,
      approved:      true,
    }));

    await Scheme.insertMany(rows);
    console.log(`✅ ${rows.length} schemes inserted successfully`);

    process.exit(0);
  } catch (error) {
    console.error("Seed failed:", error);
    process.exit(1);
  }
};

seedData();