-- ============================================================
-- 20_seed_data.sql
-- Initial seed data for QuickBite platform
-- Run AFTER all migration files
-- ============================================================

-- ------------------------------------------------------------
-- Default tenant: QuickBite India
-- ------------------------------------------------------------
INSERT INTO platform_tenants (
  id, name, slug, country_code, currency_code, timezone, locale,
  status, config
) VALUES (
  '00000000-0000-0000-0000-000000000001',
  'QuickBite India',
  'quickbite-in',
  'IN',
  'INR',
  'Asia/Kolkata',
  'en-IN',
  'active',
  '{
    "verticals_enabled": ["food","grocery","pharmacy","milk","meat","fish","gifts","flowers","pet_supplies"],
    "payment_methods": ["upi","card","cod","wallet","net_banking"],
    "features": {
      "group_ordering": true,
      "quickbite_pass": true,
      "ai_recommendations": true,
      "health_tracking": true,
      "restaurant_ai_copilot": true
    }
  }'
) ON CONFLICT (id) DO NOTHING;

-- ------------------------------------------------------------
-- Platform Verticals
-- ------------------------------------------------------------
INSERT INTO verticals (id, tenant_id, name, slug, description, sort_order, is_active) VALUES
  ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', 'Food',         'food',         'Restaurant food delivery',     1,  true),
  ('10000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000001', 'Grocery',      'grocery',      'Supermarket & kirana delivery', 2,  true),
  ('10000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000001', 'Pharmacy',     'pharmacy',     'Medicine & health products',    3,  true),
  ('10000000-0000-0000-0000-000000000004', '00000000-0000-0000-0000-000000000001', 'Milk',         'milk',         'Daily subscription milk',       4,  true),
  ('10000000-0000-0000-0000-000000000005', '00000000-0000-0000-0000-000000000001', 'Meat',         'meat',         'Fresh meat & poultry',          5,  true),
  ('10000000-0000-0000-0000-000000000006', '00000000-0000-0000-0000-000000000001', 'Fish',         'fish',         'Fresh seafood delivery',        6,  true),
  ('10000000-0000-0000-0000-000000000007', '00000000-0000-0000-0000-000000000001', 'Gifts',        'gifts',        'Gift hampers & custom gifts',   7,  true),
  ('10000000-0000-0000-0000-000000000008', '00000000-0000-0000-0000-000000000001', 'Flowers',      'flowers',      'Fresh flowers & bouquets',      8,  true),
  ('10000000-0000-0000-0000-000000000009', '00000000-0000-0000-0000-000000000001', 'Pet Supplies', 'pet-supplies', 'Pet food & accessories',        9,  true)
ON CONFLICT (id) DO NOTHING;

-- ------------------------------------------------------------
-- System Roles
-- ------------------------------------------------------------
INSERT INTO roles (id, tenant_id, name, slug, description, is_system_role) VALUES
  (gen_random_uuid(), '00000000-0000-0000-0000-000000000001', 'Customer',          'customer',          'End-user placing orders',           true),
  (gen_random_uuid(), '00000000-0000-0000-0000-000000000001', 'Merchant Owner',    'merchant_owner',    'Business owner managing stores',    true),
  (gen_random_uuid(), '00000000-0000-0000-0000-000000000001', 'Delivery Partner',  'delivery_partner',  'Gig delivery executive',            true),
  (gen_random_uuid(), '00000000-0000-0000-0000-000000000001', 'Store Manager',     'store_manager',     'Manager for a specific store',      true),
  (gen_random_uuid(), '00000000-0000-0000-0000-000000000001', 'Support Agent',     'support_agent',     'Customer support team member',      true),
  (gen_random_uuid(), '00000000-0000-0000-0000-000000000001', 'Super Admin',       'super_admin',       'Full platform access',              true),
  (gen_random_uuid(), '00000000-0000-0000-0000-000000000001', 'Finance Admin',     'finance_admin',     'Settlements and financial reports',  true),
  (gen_random_uuid(), '00000000-0000-0000-0000-000000000001', 'Content Manager',   'content_manager',   'Manages banners and CMS',           true)
ON CONFLICT DO NOTHING;

-- ------------------------------------------------------------
-- Core Permissions
-- ------------------------------------------------------------
INSERT INTO permissions (resource, action, description) VALUES
  ('order',        'read',    'View orders'),
  ('order',        'create',  'Place orders'),
  ('order',        'cancel',  'Cancel orders'),
  ('store',        'read',    'View store details'),
  ('store',        'manage',  'Manage store settings and menu'),
  ('product',      'read',    'View products'),
  ('product',      'manage',  'Create/update/delete products'),
  ('inventory',    'read',    'View inventory levels'),
  ('inventory',    'manage',  'Update inventory'),
  ('payment',      'read',    'View payment records'),
  ('settlement',   'read',    'View settlement reports'),
  ('review',       'read',    'View reviews'),
  ('review',       'write',   'Submit reviews'),
  ('review',       'moderate','Approve/reject reviews'),
  ('user',         'read',    'View user profiles'),
  ('user',         'manage',  'Manage user accounts'),
  ('delivery',     'read',    'View delivery assignments'),
  ('delivery',     'accept',  'Accept delivery assignments'),
  ('analytics',    'read',    'View analytics dashboards'),
  ('campaign',     'manage',  'Create and manage campaigns'),
  ('feature_flag', 'manage',  'Toggle feature flags'),
  ('tenant',       'manage',  'Manage tenant configuration')
ON CONFLICT (resource, action) DO NOTHING;

-- ------------------------------------------------------------
-- QuickBite Pass Subscription Plans
-- ------------------------------------------------------------
INSERT INTO subscription_plans (
  id, tenant_id, name, slug, description, plan_type,
  duration_days, price, discounted_price, currency_code,
  is_active, is_featured, sort_order, trial_days, benefits
) VALUES
  (
    gen_random_uuid(),
    '00000000-0000-0000-0000-000000000001',
    'QuickBite Pass Monthly',
    'qb-pass-monthly',
    'Free delivery, cashback & priority service every month',
    'monthly', 30, 149.00, 99.00, 'INR', true, false, 1, 7,
    '[
      {"type": "free_delivery", "description": "Free delivery on all orders"},
      {"type": "cashback_percent", "value": 5, "description": "5% cashback on every order"},
      {"type": "priority_delivery", "description": "Your orders get priority dispatch"},
      {"type": "no_surge_fee", "description": "No surge pricing during peak hours"}
    ]'
  ),
  (
    gen_random_uuid(),
    '00000000-0000-0000-0000-000000000001',
    'QuickBite Pass Quarterly',
    'qb-pass-quarterly',
    'Best value — 3 months of premium delivery benefits',
    'quarterly', 90, 399.00, 299.00, 'INR', true, true, 2, 7,
    '[
      {"type": "free_delivery", "description": "Unlimited free delivery"},
      {"type": "cashback_percent", "value": 7, "description": "7% cashback on every order"},
      {"type": "priority_delivery", "description": "Top priority dispatch always"},
      {"type": "no_surge_fee", "description": "No surge pricing ever"},
      {"type": "exclusive_discount", "value": 10, "description": "Extra 10% off on partner restaurants"}
    ]'
  ),
  (
    gen_random_uuid(),
    '00000000-0000-0000-0000-000000000001',
    'QuickBite Pass Annual',
    'qb-pass-annual',
    'Maximum savings — a full year of QuickBite Pass',
    'annual', 365, 1199.00, 799.00, 'INR', true, false, 3, 14,
    '[
      {"type": "free_delivery", "description": "Unlimited free delivery all year"},
      {"type": "cashback_percent", "value": 10, "description": "10% cashback on every order"},
      {"type": "priority_delivery", "description": "Top priority dispatch always"},
      {"type": "no_surge_fee", "description": "No surge pricing ever"},
      {"type": "exclusive_discount", "value": 15, "description": "Extra 15% off on partner restaurants"},
      {"type": "early_access", "description": "Early access to new features and restaurants"},
      {"type": "dedicated_support", "description": "Priority customer support"}
    ]'
  )
ON CONFLICT DO NOTHING;

-- ------------------------------------------------------------
-- Loyalty Tiers
-- ------------------------------------------------------------
INSERT INTO loyalty_tiers (
  id, tenant_id, name, slug, min_points, max_points,
  cashback_rate, points_multiplier, color_hex, sort_order, is_active, benefits
) VALUES
  (
    gen_random_uuid(),
    '00000000-0000-0000-0000-000000000001',
    'Bronze', 'bronze', 0, 999,
    0.5, 1.0, '#CD7F32', 1, true,
    '[{"benefit": "0.5% cashback on every order"}]'
  ),
  (
    gen_random_uuid(),
    '00000000-0000-0000-0000-000000000001',
    'Silver', 'silver', 1000, 4999,
    1.0, 1.5, '#C0C0C0', 2, true,
    '[{"benefit": "1% cashback"}, {"benefit": "1.5x points on every order"}]'
  ),
  (
    gen_random_uuid(),
    '00000000-0000-0000-0000-000000000001',
    'Gold', 'gold', 5000, 19999,
    2.0, 2.0, '#FFD700', 3, true,
    '[{"benefit": "2% cashback"}, {"benefit": "2x points"}, {"benefit": "Free delivery twice a week"}]'
  ),
  (
    gen_random_uuid(),
    '00000000-0000-0000-0000-000000000001',
    'Platinum', 'platinum', 20000, NULL,
    3.0, 3.0, '#E5E4E2', 4, true,
    '[{"benefit": "3% cashback"}, {"benefit": "3x points"}, {"benefit": "Free delivery always"}, {"benefit": "Dedicated support"}]'
  )
ON CONFLICT DO NOTHING;

-- ------------------------------------------------------------
-- Admin Roles
-- ------------------------------------------------------------
INSERT INTO admin_roles (tenant_id, name, slug, is_system_role, permissions) VALUES
  (
    '00000000-0000-0000-0000-000000000001',
    'Super Admin', 'super_admin', true,
    '["*"]'
  ),
  (
    '00000000-0000-0000-0000-000000000001',
    'Operations', 'operations', true,
    '["order:*","delivery:*","store:read","merchant:read"]'
  ),
  (
    '00000000-0000-0000-0000-000000000001',
    'Finance', 'finance', true,
    '["payment:*","settlement:*","invoice:*","analytics:read"]'
  ),
  (
    '00000000-0000-0000-0000-000000000001',
    'Support', 'support', true,
    '["support_ticket:*","user:read","order:read"]'
  ),
  (
    '00000000-0000-0000-0000-000000000001',
    'Content', 'content', true,
    '["banner:*","cms:*","promotion:*","review:moderate"]'
  )
ON CONFLICT DO NOTHING;

-- ------------------------------------------------------------
-- Feature Flags (Default configuration)
-- ------------------------------------------------------------
INSERT INTO feature_flags (
  tenant_id, key, description, flag_type, value_boolean, is_enabled, environment
) VALUES
  ('00000000-0000-0000-0000-000000000001', 'group_ordering',           'Enable group ordering feature',           'boolean', true,  true,  'production'),
  ('00000000-0000-0000-0000-000000000001', 'quickbite_pass',           'Enable QuickBite Pass subscriptions',      'boolean', true,  true,  'production'),
  ('00000000-0000-0000-0000-000000000001', 'ai_recommendations',       'Enable AI-powered recommendations',        'boolean', true,  true,  'production'),
  ('00000000-0000-0000-0000-000000000001', 'health_tracking',          'Enable health & nutrition tracking',       'boolean', true,  true,  'production'),
  ('00000000-0000-0000-0000-000000000001', 'restaurant_ai_copilot',    'Enable restaurant AI copilot for merchants','boolean',true,  true,  'production'),
  ('00000000-0000-0000-0000-000000000001', 'surge_pricing',            'Enable surge pricing during peak hours',   'boolean', false, false, 'production'),
  ('00000000-0000-0000-0000-000000000001', 'live_tracking',            'Enable real-time delivery partner tracking','boolean',true,  true,  'production'),
  ('00000000-0000-0000-0000-000000000001', 'split_payments',           'Enable split payment for group orders',    'boolean', true,  true,  'production'),
  ('00000000-0000-0000-0000-000000000001', 'meal_planning',            'Enable AI meal planning suggestions',      'boolean', false, false, 'production'),
  ('00000000-0000-0000-0000-000000000001', 'voice_search',             'Enable voice search in app',               'boolean', false, false, 'production')
ON CONFLICT DO NOTHING;

-- ------------------------------------------------------------
-- Delivery Zones (Sample — Bangalore)
-- ------------------------------------------------------------
INSERT INTO delivery_zones (
  tenant_id, name, city, state, country_code,
  base_delivery_fee, per_km_fee, surge_threshold, is_active
) VALUES
  (
    '00000000-0000-0000-0000-000000000001',
    'Bangalore North', 'Bangalore', 'Karnataka', 'IN',
    20.00, 3.50, 100, true
  ),
  (
    '00000000-0000-0000-0000-000000000001',
    'Bangalore South', 'Bangalore', 'Karnataka', 'IN',
    20.00, 3.50, 100, true
  ),
  (
    '00000000-0000-0000-0000-000000000001',
    'Bangalore East', 'Bangalore', 'Karnataka', 'IN',
    25.00, 4.00, 80, true
  ),
  (
    '00000000-0000-0000-0000-000000000001',
    'Bangalore West', 'Bangalore', 'Karnataka', 'IN',
    25.00, 4.00, 80, true
  )
ON CONFLICT DO NOTHING;

-- ------------------------------------------------------------
-- Home Screen Sections (Default layout)
-- ------------------------------------------------------------
INSERT INTO home_sections (
  tenant_id, title, subtitle, section_type, sort_order, is_active
) VALUES
  ('00000000-0000-0000-0000-000000000001', 'Featured',            NULL,                    'banner_carousel',   1, true),
  ('00000000-0000-0000-0000-000000000001', 'Delivery Categories', 'What do you want?',     'vertical_selector', 2, true),
  ('00000000-0000-0000-0000-000000000001', 'For You',             'Curated just for you',  'for_you',           3, true),
  ('00000000-0000-0000-0000-000000000001', 'Order Again',         'Your favourites',       'recently_ordered',  4, true),
  ('00000000-0000-0000-0000-000000000001', 'Trending Now',        'Popular near you',      'trending',          5, true),
  ('00000000-0000-0000-0000-000000000001', 'Top Restaurants',     'Highly rated near you', 'store_horizontal',  6, true)
ON CONFLICT DO NOTHING;

SELECT 'QuickBite seed data loaded successfully.' AS status;
