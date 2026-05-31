library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ids_hw_top is
    generic (CLK_FREQ_HZ : integer := 50_000_000);
    port (
        -- 50 MHz board oscillator (pin N18)
        clk                  : in    std_logic;
        -- Reset: PL_KEY1 active low (pin P16)
        rst_n                : in    std_logic;
        -- DDR (required by Zynq PS, routed through wrapper)
        DDR_addr             : inout std_logic_vector(14 downto 0);
        DDR_ba               : inout std_logic_vector(2 downto 0);
        DDR_cas_n            : inout std_logic;
        DDR_ck_n             : inout std_logic;
        DDR_ck_p             : inout std_logic;
        DDR_cke              : inout std_logic;
        DDR_cs_n             : inout std_logic;
        DDR_dm               : inout std_logic_vector(3 downto 0);
        DDR_dq               : inout std_logic_vector(31 downto 0);
        DDR_dqs_n            : inout std_logic_vector(3 downto 0);
        DDR_dqs_p            : inout std_logic_vector(3 downto 0);
        DDR_odt              : inout std_logic;
        DDR_ras_n            : inout std_logic;
        DDR_reset_n          : inout std_logic;
        DDR_we_n             : inout std_logic;
        -- Fixed IO (required by Zynq PS)
        FIXED_IO_ddr_vrn     : inout std_logic;
        FIXED_IO_ddr_vrp     : inout std_logic;
        FIXED_IO_mio         : inout std_logic_vector(53 downto 0);
        FIXED_IO_ps_clk      : inout std_logic;
        FIXED_IO_ps_porb     : inout std_logic;
        FIXED_IO_ps_srstb    : inout std_logic;
        -- LEDs (active LOW on Z7-Lite)
        led_alert_n          : out   std_logic;
        led_active_n         : out   std_logic;
        -- Alert outputs (for future RISC-V BRAM integration)
        alert_syn_fin        : out   std_logic;
        alert_syn_rst        : out   std_logic;
        alert_null_scan      : out   std_logic;
        alert_xmas_scan      : out   std_logic;
        alert_forbidden      : out   std_logic;
        tcp_alert_any        : out   std_logic;
        alert_udp_forbidden  : out   std_logic;
        alert_udp_short      : out   std_logic;
        alert_udp_zero       : out   std_logic;
        udp_alert_any        : out   std_logic
    );
end ids_hw_top;

architecture rtl of ids_hw_top is

    -- Block design wrapper component declaration
    component ids_system_wrapper is
        port (
            DDR_addr             : inout std_logic_vector(14 downto 0);
            DDR_ba               : inout std_logic_vector(2 downto 0);
            DDR_cas_n            : inout std_logic;
            DDR_ck_n             : inout std_logic;
            DDR_ck_p             : inout std_logic;
            DDR_cke              : inout std_logic;
            DDR_cs_n             : inout std_logic;
            DDR_dm               : inout std_logic_vector(3 downto 0);
            DDR_dq               : inout std_logic_vector(31 downto 0);
            DDR_dqs_n            : inout std_logic_vector(3 downto 0);
            DDR_dqs_p            : inout std_logic_vector(3 downto 0);
            DDR_odt              : inout std_logic;
            DDR_ras_n            : inout std_logic;
            DDR_reset_n          : inout std_logic;
            DDR_we_n             : inout std_logic;
            FIXED_IO_ddr_vrn     : inout std_logic;
            FIXED_IO_ddr_vrp     : inout std_logic;
            FIXED_IO_mio         : inout std_logic_vector(53 downto 0);
            FIXED_IO_ps_clk      : inout std_logic;
            FIXED_IO_ps_porb     : inout std_logic;
            FIXED_IO_ps_srstb    : inout std_logic;
            M_AXIS_MM2S_0_tdata  : out   std_logic_vector(7 downto 0);
            M_AXIS_MM2S_0_tkeep  : out   std_logic_vector(0 downto 0);
            M_AXIS_MM2S_0_tlast  : out   std_logic;
            M_AXIS_MM2S_0_tready : in    std_logic;
            M_AXIS_MM2S_0_tvalid : out   std_logic
        );
    end component;

    -- Internal reset (active high for IDS modules)
    signal rst : std_logic;

    -- AXI-Stream signals between wrapper and axis_rx
    signal axis_tdata  : std_logic_vector(7 downto 0);
    signal axis_tkeep  : std_logic_vector(0 downto 0);
    signal axis_tvalid : std_logic;
    signal axis_tlast  : std_logic;
    signal axis_tready : std_logic;

    -- axis_rx → byte stream
    signal rx_byte  : std_logic_vector(7 downto 0);
    signal rx_valid : std_logic;
    signal rx_sof   : std_logic;
    signal rx_eof   : std_logic;

    -- eth_parser outputs
    signal frame_done : std_logic;
    signal is_ipv4    : std_logic;
    signal is_arp     : std_logic;
    signal is_unknown : std_logic;

    -- ipv4_parser outputs
    signal ip_parse_done  : std_logic;
    signal ip_parse_valid : std_logic;
    signal ip_version     : std_logic_vector(3 downto 0);
    signal ip_ihl         : std_logic_vector(3 downto 0);
    signal ip_length      : std_logic_vector(15 downto 0);
    signal ip_flags       : std_logic_vector(2 downto 0);
    signal ip_frag_off    : std_logic_vector(12 downto 0);
    signal ip_ttl         : std_logic_vector(7 downto 0);
    signal ip_protocol    : std_logic_vector(7 downto 0);
    signal ip_src         : std_logic_vector(31 downto 0);
    signal ip_dst         : std_logic_vector(31 downto 0);

    -- ipv4_checker outputs
    signal alert_bad_version  : std_logic;
    signal alert_bad_ihl      : std_logic;
    signal alert_bad_length   : std_logic;
    signal alert_low_ttl      : std_logic;
    signal alert_fragment     : std_logic;
    signal alert_spoof_src    : std_logic;
    signal alert_land_attack  : std_logic;
    signal alert_bogon_loop   : std_logic;
    signal alert_bogon_link   : std_logic;
    signal alert_bogon_mcast  : std_logic;
    signal alert_ip_options   : std_logic;
    signal alert_reserved_bit : std_logic;
    signal alert_ipv4_any     : std_logic;

    -- tcp_parser outputs
    signal tcp_src_port    : std_logic_vector(15 downto 0);
    signal tcp_dst_port    : std_logic_vector(15 downto 0);
    signal tcp_flags_s     : std_logic_vector(7 downto 0);
    signal tcp_seq         : std_logic_vector(31 downto 0);
    signal tcp_parse_done  : std_logic;
    signal tcp_parse_valid : std_logic;
    signal tcp_alert_any_i : std_logic;

    -- udp_parser outputs
    signal udp_src_port    : std_logic_vector(15 downto 0);
    signal udp_dst_port    : std_logic_vector(15 downto 0);
    signal udp_length      : std_logic_vector(15 downto 0);
    signal udp_parse_done  : std_logic;
    signal udp_parse_valid : std_logic;

    -- udp_checker internal outputs
    signal alert_udp_zero_len  : std_logic;
    signal alert_udp_amplify   : std_logic;
    signal alert_udp_land      : std_logic;
    signal alert_udp_oversized : std_logic;
    signal alert_udp_port_zero : std_logic;
    signal alert_udp_ssdp      : std_logic;
    signal alert_udp_memcached : std_logic;
    signal udp_alert_any_i     : std_logic;

    -- LED internals
    signal led_active_i : std_logic;

    -- Alert latch
    signal alert_latch : std_logic := '0';

begin

    -- Active-high reset from active-low key
    rst <= not rst_n;

    -- LED polarity inversion (Z7-Lite LEDs are active LOW)
    led_alert_n  <= not alert_latch;
    led_active_n <= not led_active_i;

    -- Alert output assignments for RISC-V integration
    tcp_alert_any <= tcp_alert_any_i;
    udp_alert_any <= udp_alert_any_i;
    alert_udp_zero <= alert_udp_zero_len;

    -- Block design: Zynq PS + AXI DMA
    u_ps : ids_system_wrapper
        port map (
            DDR_addr             => DDR_addr,
            DDR_ba               => DDR_ba,
            DDR_cas_n            => DDR_cas_n,
            DDR_ck_n             => DDR_ck_n,
            DDR_ck_p             => DDR_ck_p,
            DDR_cke              => DDR_cke,
            DDR_cs_n             => DDR_cs_n,
            DDR_dm               => DDR_dm,
            DDR_dq               => DDR_dq,
            DDR_dqs_n            => DDR_dqs_n,
            DDR_dqs_p            => DDR_dqs_p,
            DDR_odt              => DDR_odt,
            DDR_ras_n            => DDR_ras_n,
            DDR_reset_n          => DDR_reset_n,
            DDR_we_n             => DDR_we_n,
            FIXED_IO_ddr_vrn     => FIXED_IO_ddr_vrn,
            FIXED_IO_ddr_vrp     => FIXED_IO_ddr_vrp,
            FIXED_IO_mio         => FIXED_IO_mio,
            FIXED_IO_ps_clk      => FIXED_IO_ps_clk,
            FIXED_IO_ps_porb     => FIXED_IO_ps_porb,
            FIXED_IO_ps_srstb    => FIXED_IO_ps_srstb,
            M_AXIS_MM2S_0_tdata  => axis_tdata,
            M_AXIS_MM2S_0_tkeep  => axis_tkeep,
            M_AXIS_MM2S_0_tlast  => axis_tlast,
            M_AXIS_MM2S_0_tready => axis_tready,
            M_AXIS_MM2S_0_tvalid => axis_tvalid
        );

    -- AXI-Stream to byte stream adapter
    u_axis_rx : entity work.axis_rx
        port map (
            clk           => clk,
            rst           => rst,
            s_axis_tdata  => axis_tdata,
            s_axis_tvalid => axis_tvalid,
            s_axis_tlast  => axis_tlast,
            s_axis_tready => axis_tready,
            rx_byte       => rx_byte,
            rx_valid      => rx_valid,
            rx_sof        => rx_sof,
            rx_eof        => rx_eof
        );

    -- Ethernet Parser
    u_eth_parser : entity work.eth_parser
        port map (
            clk        => clk, rst => rst,
            rx_byte    => rx_byte, rx_valid => rx_valid,
            rx_sof     => rx_sof, rx_eof => rx_eof,
            frame_done => frame_done, is_ipv4 => is_ipv4,
            is_arp     => is_arp, is_unknown => is_unknown,
            dst_mac    => open, src_mac => open, ethertype => open
        );

    -- Frame Counter + Activity LED
    u_frame_counter : entity work.frame_counter
        generic map (CLK_FREQ_HZ => CLK_FREQ_HZ)
        port map (
            clk        => clk, rst => rst,
            frame_done => frame_done, is_ipv4 => is_ipv4,
            is_arp     => is_arp, is_unknown => is_unknown,
            fps_total  => open, fps_ipv4 => open,
            fps_arp    => open, fps_unknown => open,
            led_active => led_active_i
        );

    -- IPv4 Parser
    u_ipv4_parser : entity work.ipv4_parser
        port map (
            clk         => clk, rst => rst,
            rx_byte     => rx_byte, rx_valid => rx_valid,
            rx_sof      => rx_sof, rx_eof => rx_eof,
            ip_version  => ip_version, ip_ihl => ip_ihl,
            ip_length   => ip_length, ip_flags => ip_flags,
            ip_frag_off => ip_frag_off, ip_ttl => ip_ttl,
            ip_protocol => ip_protocol,
            ip_src      => ip_src, ip_dst => ip_dst,
            parse_done  => ip_parse_done, parse_valid => ip_parse_valid
        );

    -- IPv4 Checker (R1-R12)
    u_ipv4_checker : entity work.ipv4_checker
        port map (
            clk                => clk, rst => rst,
            parse_done         => ip_parse_done,
            parse_valid        => ip_parse_valid,
            ip_version         => ip_version, ip_ihl => ip_ihl,
            ip_length          => ip_length, ip_flags => ip_flags,
            ip_frag_off        => ip_frag_off, ip_ttl => ip_ttl,
            ip_protocol        => ip_protocol,
            ip_src             => ip_src, ip_dst => ip_dst,
            bogon_check_en     => '1',
            ip_options_en      => '1',
            reserved_bit_en    => '1',
            alert_bad_version  => alert_bad_version,
            alert_bad_ihl      => alert_bad_ihl,
            alert_bad_length   => alert_bad_length,
            alert_low_ttl      => alert_low_ttl,
            alert_fragment     => alert_fragment,
            alert_spoof_src    => alert_spoof_src,
            alert_land_attack  => alert_land_attack,
            alert_bogon_loop   => alert_bogon_loop,
            alert_bogon_link   => alert_bogon_link,
            alert_bogon_mcast  => alert_bogon_mcast,
            alert_ip_options   => alert_ip_options,
            alert_reserved_bit => alert_reserved_bit,
            alert_any          => alert_ipv4_any
        );

    -- TCP Parser
    u_tcp_parser : entity work.tcp_parser
        port map (
            clk          => clk, rst => rst,
            rx_byte      => rx_byte, rx_valid => rx_valid,
            rx_sof       => rx_sof, rx_eof => rx_eof,
            ip_protocol  => ip_protocol, ip_ihl => ip_ihl,
            ip_valid     => ip_parse_done,
            tcp_src_port => tcp_src_port,
            tcp_dst_port => tcp_dst_port,
            tcp_flags    => tcp_flags_s,
            tcp_seq      => tcp_seq,
            parse_done   => tcp_parse_done,
            parse_valid  => tcp_parse_valid
        );

    -- TCP Checker (T1-T5)
    u_tcp_checker : entity work.tcp_checker
        port map (
            clk             => clk, rst => rst,
            parse_done      => tcp_parse_done,
            parse_valid     => tcp_parse_valid,
            tcp_src_port    => tcp_src_port,
            tcp_dst_port    => tcp_dst_port,
            tcp_flags       => tcp_flags_s,
            alert_syn_fin   => alert_syn_fin,
            alert_syn_rst   => alert_syn_rst,
            alert_null_scan => alert_null_scan,
            alert_xmas_scan => alert_xmas_scan,
            alert_forbidden => alert_forbidden,
            alert_any       => tcp_alert_any_i
        );

    -- UDP Parser
    u_udp_parser : entity work.udp_parser
        port map (
            clk          => clk, rst => rst,
            rx_byte      => rx_byte, rx_valid => rx_valid,
            rx_sof       => rx_sof, rx_eof => rx_eof,
            ip_protocol  => ip_protocol, ip_ihl => ip_ihl,
            ip_valid     => ip_parse_done,
            udp_src_port => udp_src_port,
            udp_dst_port => udp_dst_port,
            udp_length   => udp_length,
            parse_done   => udp_parse_done,
            parse_valid  => udp_parse_valid
        );

    -- UDP Checker (U1-U9)
    u_udp_checker : entity work.udp_checker
        port map (
            clk                 => clk, rst => rst,
            parse_done          => udp_parse_done,
            parse_valid         => udp_parse_valid,
            udp_src_port        => udp_src_port,
            udp_dst_port        => udp_dst_port,
            udp_length          => udp_length,
            ip_src              => ip_src,
            ip_dst              => ip_dst,
            forbidden_port_0    => x"0035",
            forbidden_port_1    => x"007B",
            forbidden_port_2    => x"0000",
            forbidden_port_3    => x"0000",
            forbidden_port_4    => x"0000",
            forbidden_port_5    => x"0000",
            forbidden_port_6    => x"0000",
            forbidden_port_7    => x"0000",
            alert_udp_forbidden => alert_udp_forbidden,
            alert_udp_short     => alert_udp_short,
            alert_udp_zero_len  => alert_udp_zero_len,
            alert_udp_amplify   => alert_udp_amplify,
            alert_udp_land      => alert_udp_land,
            alert_udp_oversized => alert_udp_oversized,
            alert_udp_port_zero => alert_udp_port_zero,
            alert_udp_ssdp      => alert_udp_ssdp,
            alert_udp_memcached => alert_udp_memcached,
            alert_any           => udp_alert_any_i
        );

    -- Alert latch: any alert from any layer latches LED on
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                alert_latch <= '0';
            elsif alert_ipv4_any = '1'
               or tcp_alert_any_i = '1'
               or udp_alert_any_i = '1' then
                alert_latch <= '1';
            end if;
        end if;
    end process;

end rtl;