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
          id: string
          league: string
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
          id?: string
          league?: string
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
          id?: string
          league?: string
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
      process_game_week: { Args: never; Returns: Json }
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
