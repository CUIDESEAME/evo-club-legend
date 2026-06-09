export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  // Allows to automatically instantiate createClient with right options
  // instead of createClient<Database, { PostgrestVersion: 'XX' }>(URL, KEY)
  __InternalSupabase: {
    PostgrestVersion: "14.4"
  }
  public: {
    Tables: {
      bank_deposits: {
        Row: {
          club_id: string
          created_at: string
          id: string
          interest_rate: number
          matured_at: string | null
          principal: number
          status: string
          weeks: number
          weeks_remaining: number
        }
        Insert: {
          club_id: string
          created_at?: string
          id?: string
          interest_rate?: number
          matured_at?: string | null
          principal: number
          status?: string
          weeks: number
          weeks_remaining: number
        }
        Update: {
          club_id?: string
          created_at?: string
          id?: string
          interest_rate?: number
          matured_at?: string | null
          principal?: number
          status?: string
          weeks?: number
          weeks_remaining?: number
        }
        Relationships: []
      }
      club_trophies: {
        Row: {
          club_id: string
          competition_name: string
          created_at: string
          id: string
          position: string
          season_number: number
          trophy_type: string
        }
        Insert: {
          club_id: string
          competition_name: string
          created_at?: string
          id?: string
          position?: string
          season_number: number
          trophy_type: string
        }
        Update: {
          club_id?: string
          competition_name?: string
          created_at?: string
          id?: string
          position?: string
          season_number?: number
          trophy_type?: string
        }
        Relationships: []
      }
      clubs: {
        Row: {
          abbreviation: string
          balance: number
          created_at: string
          division: number
          fans: number
          founded_at: string
          game_week: number
          id: string
          league: string
          marketing_budget: number
          members: number
          name: string
          updated_at: string
          user_id: string
        }
        Insert: {
          abbreviation: string
          balance?: number
          created_at?: string
          division?: number
          fans?: number
          founded_at?: string
          game_week?: number
          id?: string
          league?: string
          marketing_budget?: number
          members?: number
          name: string
          updated_at?: string
          user_id: string
        }
        Update: {
          abbreviation?: string
          balance?: number
          created_at?: string
          division?: number
          fans?: number
          founded_at?: string
          game_week?: number
          id?: string
          league?: string
          marketing_budget?: number
          members?: number
          name?: string
          updated_at?: string
          user_id?: string
        }
        Relationships: []
      }
      cup_entries: {
        Row: {
          club_id: string
          cup_id: string
          id: string
          prize_received: number
          reached_phase: string | null
          registered_at: string
          status: string
        }
        Insert: {
          club_id: string
          cup_id: string
          id?: string
          prize_received?: number
          reached_phase?: string | null
          registered_at?: string
          status?: string
        }
        Update: {
          club_id?: string
          cup_id?: string
          id?: string
          prize_received?: number
          reached_phase?: string | null
          registered_at?: string
          status?: string
        }
        Relationships: [
          {
            foreignKeyName: "cup_entries_cup_id_fkey"
            columns: ["cup_id"]
            isOneToOne: false
            referencedRelation: "cups"
            referencedColumns: ["id"]
          },
        ]
      }
      cup_matches: {
        Row: {
          away_club_id: string | null
          away_score: number | null
          created_at: string
          cup_id: string
          home_club_id: string | null
          home_score: number | null
          id: string
          phase: string
          played_at: string | null
          status: string
        }
        Insert: {
          away_club_id?: string | null
          away_score?: number | null
          created_at?: string
          cup_id: string
          home_club_id?: string | null
          home_score?: number | null
          id?: string
          phase: string
          played_at?: string | null
          status?: string
        }
        Update: {
          away_club_id?: string | null
          away_score?: number | null
          created_at?: string
          cup_id?: string
          home_club_id?: string | null
          home_score?: number | null
          id?: string
          phase?: string
          played_at?: string | null
          status?: string
        }
        Relationships: []
      }
      cups: {
        Row: {
          champion_prize: number
          created_at: string
          cup_type: string
          entry_fee: number
          id: string
          name: string
          runner_up_prize: number
          semifinal_prize: number
          starts_at: string
          status: string
        }
        Insert: {
          champion_prize?: number
          created_at?: string
          cup_type?: string
          entry_fee?: number
          id?: string
          name: string
          runner_up_prize?: number
          semifinal_prize?: number
          starts_at?: string
          status?: string
        }
        Update: {
          champion_prize?: number
          created_at?: string
          cup_type?: string
          entry_fee?: number
          id?: string
          name?: string
          runner_up_prize?: number
          semifinal_prize?: number
          starts_at?: string
          status?: string
        }
        Relationships: []
      }
      disciplinary_events: {
        Row: {
          club_id: string
          created_at: string
          description: string
          event_type: string
          fine_amount: number
          id: string
          player_id: string
          weeks_suspended: number
        }
        Insert: {
          club_id: string
          created_at?: string
          description: string
          event_type: string
          fine_amount?: number
          id?: string
          player_id: string
          weeks_suspended?: number
        }
        Update: {
          club_id?: string
          created_at?: string
          description?: string
          event_type?: string
          fine_amount?: number
          id?: string
          player_id?: string
          weeks_suspended?: number
        }
        Relationships: []
      }
      financial_transactions: {
        Row: {
          amount: number
          balance_after: number
          club_id: string
          created_at: string
          description: string
          id: string
          type: string
        }
        Insert: {
          amount: number
          balance_after: number
          club_id: string
          created_at?: string
          description: string
          id?: string
          type: string
        }
        Update: {
          amount?: number
          balance_after?: number
          club_id?: string
          created_at?: string
          description?: string
          id?: string
          type?: string
        }
        Relationships: [
          {
            foreignKeyName: "financial_transactions_club_id_fkey"
            columns: ["club_id"]
            isOneToOne: false
            referencedRelation: "clubs"
            referencedColumns: ["id"]
          },
        ]
      }
      junior_investments: {
        Row: {
          club_id: string
          created_at: string
          id: string
          junior_id: string
          week_number: number
        }
        Insert: {
          club_id: string
          created_at?: string
          id?: string
          junior_id: string
          week_number: number
        }
        Update: {
          club_id?: string
          created_at?: string
          id?: string
          junior_id?: string
          week_number?: number
        }
        Relationships: [
          {
            foreignKeyName: "junior_investments_club_id_fkey"
            columns: ["club_id"]
            isOneToOne: false
            referencedRelation: "clubs"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "junior_investments_junior_id_fkey"
            columns: ["junior_id"]
            isOneToOne: false
            referencedRelation: "juniors"
            referencedColumns: ["id"]
          },
        ]
      }
      juniors: {
        Row: {
          age: number
          club_id: string
          created_at: string
          id: string
          name: string
          position: Database["public"]["Enums"]["player_position"]
          quality: number
          revealed: boolean
          talento: number
          updated_at: string
          weeks_to_reveal: number
        }
        Insert: {
          age?: number
          club_id: string
          created_at?: string
          id?: string
          name: string
          position: Database["public"]["Enums"]["player_position"]
          quality?: number
          revealed?: boolean
          talento?: number
          updated_at?: string
          weeks_to_reveal?: number
        }
        Update: {
          age?: number
          club_id?: string
          created_at?: string
          id?: string
          name?: string
          position?: Database["public"]["Enums"]["player_position"]
          quality?: number
          revealed?: boolean
          talento?: number
          updated_at?: string
          weeks_to_reveal?: number
        }
        Relationships: [
          {
            foreignKeyName: "juniors_club_id_fkey"
            columns: ["club_id"]
            isOneToOne: false
            referencedRelation: "clubs"
            referencedColumns: ["id"]
          },
        ]
      }
      league_standings: {
        Row: {
          club_id: string | null
          created_at: string
          draws: number
          goals_against: number
          goals_for: number
          id: string
          losses: number
          npc_club_id: string | null
          played: number
          points: number
          season_id: string
          wins: number
        }
        Insert: {
          club_id?: string | null
          created_at?: string
          draws?: number
          goals_against?: number
          goals_for?: number
          id?: string
          losses?: number
          npc_club_id?: string | null
          played?: number
          points?: number
          season_id: string
          wins?: number
        }
        Update: {
          club_id?: string | null
          created_at?: string
          draws?: number
          goals_against?: number
          goals_for?: number
          id?: string
          losses?: number
          npc_club_id?: string | null
          played?: number
          points?: number
          season_id?: string
          wins?: number
        }
        Relationships: [
          {
            foreignKeyName: "league_standings_club_id_fkey"
            columns: ["club_id"]
            isOneToOne: false
            referencedRelation: "clubs"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "league_standings_npc_club_id_fkey"
            columns: ["npc_club_id"]
            isOneToOne: false
            referencedRelation: "npc_clubs"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "league_standings_season_id_fkey"
            columns: ["season_id"]
            isOneToOne: false
            referencedRelation: "seasons"
            referencedColumns: ["id"]
          },
        ]
      }
      lineup_players: {
        Row: {
          created_at: string
          id: string
          lineup_id: string
          player_id: string
          position_override: string | null
          position_slot: number
        }
        Insert: {
          created_at?: string
          id?: string
          lineup_id: string
          player_id: string
          position_override?: string | null
          position_slot: number
        }
        Update: {
          created_at?: string
          id?: string
          lineup_id?: string
          player_id?: string
          position_override?: string | null
          position_slot?: number
        }
        Relationships: [
          {
            foreignKeyName: "lineup_players_lineup_id_fkey"
            columns: ["lineup_id"]
            isOneToOne: false
            referencedRelation: "lineups"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "lineup_players_player_id_fkey"
            columns: ["player_id"]
            isOneToOne: false
            referencedRelation: "players"
            referencedColumns: ["id"]
          },
        ]
      }
      lineups: {
        Row: {
          club_id: string
          created_at: string
          formation: string
          id: string
          marking_style: string
          passing_style: string
          positioning_style: string
          updated_at: string
        }
        Insert: {
          club_id: string
          created_at?: string
          formation?: string
          id?: string
          marking_style?: string
          passing_style?: string
          positioning_style?: string
          updated_at?: string
        }
        Update: {
          club_id?: string
          created_at?: string
          formation?: string
          id?: string
          marking_style?: string
          passing_style?: string
          positioning_style?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "lineups_club_id_fkey"
            columns: ["club_id"]
            isOneToOne: true
            referencedRelation: "clubs"
            referencedColumns: ["id"]
          },
        ]
      }
      loans: {
        Row: {
          club_id: string
          created_at: string
          id: string
          interest_rate: number
          paid_amount: number
          principal: number
          remaining_weeks: number
          status: string
          total_weeks: number
          updated_at: string
          weekly_payment: number
        }
        Insert: {
          club_id: string
          created_at?: string
          id?: string
          interest_rate?: number
          paid_amount?: number
          principal: number
          remaining_weeks: number
          status?: string
          total_weeks?: number
          updated_at?: string
          weekly_payment: number
        }
        Update: {
          club_id?: string
          created_at?: string
          id?: string
          interest_rate?: number
          paid_amount?: number
          principal?: number
          remaining_weeks?: number
          status?: string
          total_weeks?: number
          updated_at?: string
          weekly_payment?: number
        }
        Relationships: []
      }
      market_closed: {
        Row: {
          age: number
          created_at: string
          id: string
          league: string
          name: string
          overall: number
          position: string
          price: number
          purchased_at: string | null
          purchased_by: string | null
          salary: number
          stats: Json
        }
        Insert: {
          age: number
          created_at?: string
          id?: string
          league?: string
          name: string
          overall?: number
          position: string
          price?: number
          purchased_at?: string | null
          purchased_by?: string | null
          salary?: number
          stats?: Json
        }
        Update: {
          age?: number
          created_at?: string
          id?: string
          league?: string
          name?: string
          overall?: number
          position?: string
          price?: number
          purchased_at?: string | null
          purchased_by?: string | null
          salary?: number
          stats?: Json
        }
        Relationships: [
          {
            foreignKeyName: "market_closed_purchased_by_fkey"
            columns: ["purchased_by"]
            isOneToOne: false
            referencedRelation: "clubs"
            referencedColumns: ["id"]
          },
        ]
      }
      market_open: {
        Row: {
          created_at: string
          current_bid: number | null
          current_bidder_club_id: string | null
          ends_at: string
          id: string
          loan_system_pct: number
          market_fee_pct: number
          min_price: number
          player_id: string
          prize_reserve_pct: number
          seller_club_id: string
          status: string
        }
        Insert: {
          created_at?: string
          current_bid?: number | null
          current_bidder_club_id?: string | null
          ends_at: string
          id?: string
          loan_system_pct?: number
          market_fee_pct?: number
          min_price?: number
          player_id: string
          prize_reserve_pct?: number
          seller_club_id: string
          status?: string
        }
        Update: {
          created_at?: string
          current_bid?: number | null
          current_bidder_club_id?: string | null
          ends_at?: string
          id?: string
          loan_system_pct?: number
          market_fee_pct?: number
          min_price?: number
          player_id?: string
          prize_reserve_pct?: number
          seller_club_id?: string
          status?: string
        }
        Relationships: [
          {
            foreignKeyName: "market_open_current_bidder_club_id_fkey"
            columns: ["current_bidder_club_id"]
            isOneToOne: false
            referencedRelation: "clubs"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "market_open_player_id_fkey"
            columns: ["player_id"]
            isOneToOne: false
            referencedRelation: "players"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "market_open_seller_club_id_fkey"
            columns: ["seller_club_id"]
            isOneToOne: false
            referencedRelation: "clubs"
            referencedColumns: ["id"]
          },
        ]
      }
      matches: {
        Row: {
          away_club_id: string | null
          away_npc_id: string | null
          away_score: number | null
          created_at: string
          home_club_id: string | null
          home_npc_id: string | null
          home_score: number | null
          id: string
          played_at: string | null
          revenue: number
          round: number
          season_id: string
          status: string
        }
        Insert: {
          away_club_id?: string | null
          away_npc_id?: string | null
          away_score?: number | null
          created_at?: string
          home_club_id?: string | null
          home_npc_id?: string | null
          home_score?: number | null
          id?: string
          played_at?: string | null
          revenue?: number
          round?: number
          season_id: string
          status?: string
        }
        Update: {
          away_club_id?: string | null
          away_npc_id?: string | null
          away_score?: number | null
          created_at?: string
          home_club_id?: string | null
          home_npc_id?: string | null
          home_score?: number | null
          id?: string
          played_at?: string | null
          revenue?: number
          round?: number
          season_id?: string
          status?: string
        }
        Relationships: [
          {
            foreignKeyName: "matches_away_club_id_fkey"
            columns: ["away_club_id"]
            isOneToOne: false
            referencedRelation: "clubs"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "matches_away_npc_id_fkey"
            columns: ["away_npc_id"]
            isOneToOne: false
            referencedRelation: "npc_clubs"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "matches_home_club_id_fkey"
            columns: ["home_club_id"]
            isOneToOne: false
            referencedRelation: "clubs"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "matches_home_npc_id_fkey"
            columns: ["home_npc_id"]
            isOneToOne: false
            referencedRelation: "npc_clubs"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "matches_season_id_fkey"
            columns: ["season_id"]
            isOneToOne: false
            referencedRelation: "seasons"
            referencedColumns: ["id"]
          },
        ]
      }
      npc_clubs: {
        Row: {
          abbreviation: string
          created_at: string
          division: number
          fan_base: number
          id: string
          league: string
          name: string
          season_id: string
          strength: number
        }
        Insert: {
          abbreviation: string
          created_at?: string
          division?: number
          fan_base?: number
          id?: string
          league?: string
          name: string
          season_id: string
          strength?: number
        }
        Update: {
          abbreviation?: string
          created_at?: string
          division?: number
          fan_base?: number
          id?: string
          league?: string
          name?: string
          season_id?: string
          strength?: number
        }
        Relationships: [
          {
            foreignKeyName: "npc_clubs_season_id_fkey"
            columns: ["season_id"]
            isOneToOne: false
            referencedRelation: "seasons"
            referencedColumns: ["id"]
          },
        ]
      }
      patrimony: {
        Row: {
          club_id: string
          construction_weeks_remaining: number
          created_at: string
          id: string
          level: number
          maintenance_cost: number
          max_level: number
          type: string
          updated_at: string
        }
        Insert: {
          club_id: string
          construction_weeks_remaining?: number
          created_at?: string
          id?: string
          level?: number
          maintenance_cost?: number
          max_level?: number
          type: string
          updated_at?: string
        }
        Update: {
          club_id?: string
          construction_weeks_remaining?: number
          created_at?: string
          id?: string
          level?: number
          maintenance_cost?: number
          max_level?: number
          type?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "patrimony_club_id_fkey"
            columns: ["club_id"]
            isOneToOne: false
            referencedRelation: "clubs"
            referencedColumns: ["id"]
          },
        ]
      }
      player_agents: {
        Row: {
          agent_name: string
          fee_pct: number
          id: string
          player_id: string
          signed_at: string
        }
        Insert: {
          agent_name: string
          fee_pct?: number
          id?: string
          player_id: string
          signed_at?: string
        }
        Update: {
          agent_name?: string
          fee_pct?: number
          id?: string
          player_id?: string
          signed_at?: string
        }
        Relationships: []
      }
      players: {
        Row: {
          age: number
          agressividade: number
          armacao: number
          chute: number
          club_id: string
          created_at: string
          desarme: number
          entrosamento: number
          experiencia: number
          fadiga: number
          forca: number
          forma: number
          honestidade: number
          id: string
          injury_weeks: number
          inteligencia: number
          is_captain: boolean
          is_for_sale: boolean
          is_injured: boolean
          jogo_aereo: number
          lideranca: number
          market_value: number
          moral: number
          name: string
          passe: number
          posicionamento: number
          position: Database["public"]["Enums"]["player_position"]
          potencial_forca: number
          potencial_forma: number
          potencial_resistencia: number
          potencial_velocidade: number
          reflexos: number
          resistencia: number
          salary: number
          talento: number
          tecnica: number
          updated_at: string
          velocidade: number
        }
        Insert: {
          age: number
          agressividade?: number
          armacao?: number
          chute?: number
          club_id: string
          created_at?: string
          desarme?: number
          entrosamento?: number
          experiencia?: number
          fadiga?: number
          forca?: number
          forma?: number
          honestidade?: number
          id?: string
          injury_weeks?: number
          inteligencia?: number
          is_captain?: boolean
          is_for_sale?: boolean
          is_injured?: boolean
          jogo_aereo?: number
          lideranca?: number
          market_value?: number
          moral?: number
          name: string
          passe?: number
          posicionamento?: number
          position: Database["public"]["Enums"]["player_position"]
          potencial_forca?: number
          potencial_forma?: number
          potencial_resistencia?: number
          potencial_velocidade?: number
          reflexos?: number
          resistencia?: number
          salary?: number
          talento?: number
          tecnica?: number
          updated_at?: string
          velocidade?: number
        }
        Update: {
          age?: number
          agressividade?: number
          armacao?: number
          chute?: number
          club_id?: string
          created_at?: string
          desarme?: number
          entrosamento?: number
          experiencia?: number
          fadiga?: number
          forca?: number
          forma?: number
          honestidade?: number
          id?: string
          injury_weeks?: number
          inteligencia?: number
          is_captain?: boolean
          is_for_sale?: boolean
          is_injured?: boolean
          jogo_aereo?: number
          lideranca?: number
          market_value?: number
          moral?: number
          name?: string
          passe?: number
          posicionamento?: number
          position?: Database["public"]["Enums"]["player_position"]
          potencial_forca?: number
          potencial_forma?: number
          potencial_resistencia?: number
          potencial_velocidade?: number
          reflexos?: number
          resistencia?: number
          salary?: number
          talento?: number
          tecnica?: number
          updated_at?: string
          velocidade?: number
        }
        Relationships: [
          {
            foreignKeyName: "players_club_id_fkey"
            columns: ["club_id"]
            isOneToOne: false
            referencedRelation: "clubs"
            referencedColumns: ["id"]
          },
        ]
      }
      profiles: {
        Row: {
          avatar_url: string | null
          created_at: string
          id: string
          updated_at: string
          user_id: string
          username: string
        }
        Insert: {
          avatar_url?: string | null
          created_at?: string
          id?: string
          updated_at?: string
          user_id: string
          username: string
        }
        Update: {
          avatar_url?: string | null
          created_at?: string
          id?: string
          updated_at?: string
          user_id?: string
          username?: string
        }
        Relationships: []
      }
      seasons: {
        Row: {
          created_at: string
          current_round: number
          division: number
          id: string
          league: string
          season_number: number
          status: string
          total_rounds: number
        }
        Insert: {
          created_at?: string
          current_round?: number
          division?: number
          id?: string
          league?: string
          season_number?: number
          status?: string
          total_rounds?: number
        }
        Update: {
          created_at?: string
          current_round?: number
          division?: number
          id?: string
          league?: string
          season_number?: number
          status?: string
          total_rounds?: number
        }
        Relationships: []
      }
      stadium_sectors: {
        Row: {
          capacity: number
          club_id: string
          created_at: string
          id: string
          ring: number
          seat_type: string
          sector_name: string
          structure: string
          updated_at: string
        }
        Insert: {
          capacity?: number
          club_id: string
          created_at?: string
          id?: string
          ring?: number
          seat_type?: string
          sector_name: string
          structure?: string
          updated_at?: string
        }
        Update: {
          capacity?: number
          club_id?: string
          created_at?: string
          id?: string
          ring?: number
          seat_type?: string
          sector_name?: string
          structure?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "stadium_sectors_club_id_fkey"
            columns: ["club_id"]
            isOneToOne: false
            referencedRelation: "clubs"
            referencedColumns: ["id"]
          },
        ]
      }
      system_funds: {
        Row: {
          balance: number
          fund_type: string
          id: string
          updated_at: string
        }
        Insert: {
          balance?: number
          fund_type: string
          id?: string
          updated_at?: string
        }
        Update: {
          balance?: number
          fund_type?: string
          id?: string
          updated_at?: string
        }
        Relationships: []
      }
      training_config: {
        Row: {
          club_id: string
          coach_level: number
          created_at: string
          fitness_coach_level: number
          id: string
          physical_intensity: number
          physical_type: string
          technical_type: string
          updated_at: string
        }
        Insert: {
          club_id: string
          coach_level?: number
          created_at?: string
          fitness_coach_level?: number
          id?: string
          physical_intensity?: number
          physical_type?: string
          technical_type?: string
          updated_at?: string
        }
        Update: {
          club_id?: string
          coach_level?: number
          created_at?: string
          fitness_coach_level?: number
          id?: string
          physical_intensity?: number
          physical_type?: string
          technical_type?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "training_config_club_id_fkey"
            columns: ["club_id"]
            isOneToOne: true
            referencedRelation: "clubs"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      advance_cup_phase: { Args: { p_cup_id: string }; Returns: Json }
      advance_season: { Args: { p_season_id: string }; Returns: Json }
      build_division_season: {
        Args: { p_clubs: string[]; p_division: number; p_league: string }
        Returns: string
      }
      buy_from_closed_market: {
        Args: { p_club_id: string; p_listing_id: string }
        Returns: Json
      }
      cleanup_old_data: { Args: never; Returns: Json }
      create_bank_deposit: {
        Args: { p_amount: number; p_club_id: string; p_weeks: number }
        Returns: Json
      }
      cup_team_strength: {
        Args: { p_id: string; p_u20: boolean }
        Returns: number
      }
      downgrade_patrimony:
        | {
            Args: {
              p_club_id: string
              p_description: string
              p_patrimony_id: string
              p_refund: number
            }
            Returns: undefined
          }
        | {
            Args: {
              p_club_id: string
              p_description: string
              p_new_level: number
              p_new_maintenance: number
              p_patrimony_id: string
              p_refund: number
            }
            Returns: undefined
          }
      end_season: { Args: { p_season_id: string }; Returns: undefined }
      finalize_auctions: { Args: never; Returns: Json }
      initialize_season_for_club: {
        Args: { p_club_id: string }
        Returns: string
      }
      invest_in_junior: {
        Args: { p_club_id: string; p_junior_id: string }
        Returns: Json
      }
      list_player_for_sale: {
        Args: { p_club_id: string; p_min_price: number; p_player_id: string }
        Returns: string
      }
      npc_auto_bid: { Args: never; Returns: Json }
      place_bid: {
        Args: { p_bid: number; p_club_id: string; p_listing_id: string }
        Returns: undefined
      }
      populate_cup: { Args: { p_cup_id: string }; Returns: Json }
      process_agent_negotiations: { Args: never; Returns: undefined }
      process_bank_deposits: { Args: never; Returns: Json }
      process_disciplinary_events: { Args: never; Returns: undefined }
      process_game_week: { Args: never; Returns: Json }
      process_sporadic_events: { Args: never; Returns: Json }
      refill_closed_market: { Args: never; Returns: Json }
      register_cup: {
        Args: { p_club_id: string; p_cup_id: string }
        Returns: Json
      }
      repair_game_progression: { Args: never; Returns: Json }
      repay_loan: {
        Args: { p_club_id: string; p_loan_id: string }
        Returns: Json
      }
      request_loan: {
        Args: { p_amount: number; p_club_id: string; p_weeks: number }
        Returns: Json
      }
      retire_player: { Args: { p_player_id: string }; Returns: Json }
      scout_junior: {
        Args: { p_club_id: string; p_tier: string }
        Returns: Json
      }
      setup_division_seasons: { Args: never; Returns: undefined }
      setup_shared_season: { Args: never; Returns: string }
      simulate_matches: { Args: never; Returns: Json }
      take_loan: {
        Args: { p_amount: number; p_club_id: string }
        Returns: undefined
      }
      upgrade_patrimony: {
        Args: {
          p_build_weeks: number
          p_club_id: string
          p_cost: number
          p_description: string
          p_new_level: number
          p_new_maintenance: number
          p_patrimony_id: string
        }
        Returns: undefined
      }
    }
    Enums: {
      player_position:
        | "goleiro"
        | "libero"
        | "zagueiro"
        | "lateral"
        | "volante"
        | "meia"
        | "ala"
        | "meia_atacante"
        | "ponteiro"
        | "atacante"
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  public: {
    Enums: {
      player_position: [
        "goleiro",
        "libero",
        "zagueiro",
        "lateral",
        "volante",
        "meia",
        "ala",
        "meia_atacante",
        "ponteiro",
        "atacante",
      ],
    },
  },
} as const
