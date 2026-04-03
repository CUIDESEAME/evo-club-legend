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
      end_season: { Args: { p_season_id: string }; Returns: undefined }
      initialize_season_for_club: {
        Args: { p_club_id: string }
        Returns: string
      }
      invest_in_junior: {
        Args: { p_club_id: string; p_junior_id: string }
        Returns: Json
      }
      process_game_week: { Args: never; Returns: Json }
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
